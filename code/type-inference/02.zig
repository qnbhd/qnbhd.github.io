const std = @import("std");

pub const Kind = union(enum) {
    star: void, // simplest option
    kfun: struct { left: *const Kind, right: *const Kind },

    pub fn isStar(a: Kind) bool {
        return switch (a) {
            .star => true,
            else => false,
        };
    }

    pub fn isKFun(a: Kind) bool {
        return switch (a) {
            .kfun => true,
            else => false,
        };
    }

    pub fn eql(a: *const Kind, b: *const Kind) bool {
        return switch (a.*) {
            .star => b.* == .star,
            .kfun => |a_fun| switch (b.*) {
                .star => false,
                .kfun => |b_fun| a_fun.left.eql(b_fun.left) and
                    a_fun.right.eql(b_fun.right),
            },
        };
    }

    pub fn format(self: Kind, w: anytype) !void {
        switch (self) {
            .star => try w.writeAll("*"),
            .kfun => |f| {
                try w.writeAll("(");
                try f.left.format(w);
                try w.writeAll(" -> ");
                try f.right.format(w);
                try w.writeAll(")");
            },
        }
    }
};

pub const Id = u32;
pub const TyVar = struct {
    id: Id,
    kind: Kind,

    pub fn star(id: Id) TyVar {
        return .{ .id = id, .kind = .star };
    }

    pub fn getKind(self: TyVar) Kind {
        return self.kind;
    }

    pub fn eql(self: TyVar, other: TyVar) bool {
        return self.id == other.id and Kind.eql(&self.kind, &other.kind);
    }
};

pub const TyCon = struct {
    name: []const u8,
    kind: Kind,

    pub fn getKind(self: TyCon) Kind {
        return self.kind;
    }
};

pub const GenId = u32;

pub const Type = union(enum) {
    tvar: TyVar,
    tcon: TyCon,
    tapp: struct { left: *const Type, right: *const Type },
    tgen: GenId,

    pub fn typevar(id: Id, kind: Kind) Type {
        return .{ .tvar = TyVar{ .id = id, .kind = kind } };
    }

    pub fn typecon(name: []const u8, kind: Kind) Type {
        return .{ .tcon = TyCon{ .name = name, .kind = kind } };
    }

    pub fn typeapp(left: *const Type, right: *const Type) Type {
        return .{ .tapp = .{ .left = left, .right = right } };
    }

    pub fn typeappAlloc(left: Type, right: Type, alloc: std.mem.Allocator) !Type {
        const l_ptr = try alloc.create(Type);
        const r_ptr = try alloc.create(Type);
        l_ptr.* = left;
        r_ptr.* = right;
        return Type.typeapp(l_ptr, r_ptr);
    }

    pub fn typegen(id: GenId) Type {
        return .{ .tgen = id };
    }

    pub fn getKind(self: Type) Kind {
        return switch (self) {
            .tvar => |s| s.getKind(),
            .tcon => |c| c.getKind(),
            .tapp => |a| blk: {
                const k = a.left.getKind();
                switch (k) {
                    .kfun => |f| break :blk f.right.*,
                    // Assumes well-kinded type application: left kind must be KFun
                    else => unreachable,
                }
            },

            // TGen must be used only in type schemas
            // And kinds of TGen's stored separately in Qual's
            // That will be described later in future parts of article
            .tgen => unreachable,
        };
    }

    // NOTE: With ArenaAllocator, allocations are batched and freed together
    pub fn apply(
        ty: *const Type,
        subst: *const Sub,
        alloc: std.mem.Allocator,
    ) !Type {
        return switch (ty.*) {
            .tvar => |tv| {
                if (subst.get(tv)) |replacement| {
                    return replacement.*;
                } else {
                    return ty.*;
                }
            },
            .tcon => ty.*,
            .tgen => ty.*,
            .tapp => |app| {
                const l = try apply(app.left, subst, alloc);
                const r = try apply(app.right, subst, alloc);
                return Type.typeappAlloc(l, r, alloc);
            },
        };
    }

    pub fn format(self: Type, w: *std.io.Writer) !void {
        switch (self) {
            .tvar => |v| try w.print("TVar({d})", .{v.id}),
            .tcon => |c| try w.print("{s}", .{c.name}),
            .tgen => |g| try w.print("TGen({d})", .{g}),
            .tapp => |a| {
                try w.print("({f} {f})", .{ a.left, a.right });
            },
        }
    }
};

pub const Sub = struct {
    map: std.AutoArrayHashMapUnmanaged(TyVar, Type),

    pub fn empty() Sub {
        return .empty;
    }

    pub fn one(tv: TyVar, ty: Type, alloc: std.mem.Allocator) !Sub {
        var map: std.AutoArrayHashMapUnmanaged(TyVar, Type) = .empty;
        try map.put(alloc, tv, ty);
        return .{ .map = map };
    }

    pub fn put(self: *Sub, tv: TyVar, ty: Type, alloc: std.mem.Allocator) !void {
        try self.map.put(alloc, tv, ty);
    }

    pub fn deinit(self: *Sub, alloc: std.mem.Allocator) void {
        self.map.deinit(alloc);
        return;
    }

    pub fn format(self: *const Sub, w: anytype) !void {
        var it = self.map.iterator();
        var first = true;
        try w.writeAll("{ ");
        while (it.next()) |entry| {
            if (!first) {
                try w.writeAll(", ");
            }
            first = false;

            try w.print("?{} ↦ ", .{entry.key_ptr.*.id});
            try entry.value_ptr.*.format(w);
        }
        try w.writeAll(" }");
    }

    pub fn get(self: *const Sub, tv: TyVar) ?*const Type {
        return self.map.getPtr(tv);
    }

    pub fn contains(self: *const Sub, tv: TyVar) bool {
        return self.map.contains(tv);
    }

    // NOTE: important! we use left-associative shadowing composition definition
    // substitution updates with only more actual data
    // it's a part of design!
    pub fn compose(self: *const Sub, other: *const Sub, allocator: std.mem.Allocator) !Sub {
        var acc: Sub = .{ .map = .empty };
        var it = other.map.iterator();
        while (it.next()) |entry| {
            const tv = entry.key_ptr.*;
            const ty = entry.value_ptr.*;
            const new_ty = try ty.apply(self, allocator);
            try acc.map.put(allocator, tv, new_ty);
        }
        it = self.map.iterator();
        while (it.next()) |entry| {
            try acc.map.put(
                allocator,
                entry.key_ptr.*,
                entry.value_ptr.*,
            );
        }
        return acc;
    }
};

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    // --- Kind: * ---
    const kstar: Kind = .star;

    const kstar_ptr = try alloc.create(Kind);
    kstar_ptr.* = Kind.star;
    const kstarstar = Kind{ .kfun = .{ .left = kstar_ptr, .right = kstar_ptr } };

    // --- Type variables ---
    const a = TyVar{ .id = 0, .kind = kstarstar }; // a :: * -> *
    const b = TyVar.star(1); // b :: *
    const c = TyVar.star(2); // c :: *

    // --- Type constructors ---
    const tInt = Type.typecon("Int", kstar);
    const tBool = Type.typecon("Bool", kstar);

    // --- Build type: (a b)
    const a_ty = Type.typevar(a.id, a.kind);
    const b_ty = Type.typevar(b.id, b.kind);

    var app = try Type.typeappAlloc(a_ty, b_ty, alloc);

    std.debug.print("Original type: ", .{});
    std.debug.print("{f}\n", .{app});

    // --- Substitution s1 = [ a ↦ Int ]
    var s1 = try Sub.one(a, tInt, alloc);

    // --- Apply s1 to type
    const app1 = try Type.apply(&app, &s1, alloc);

    std.debug.print("After applying s1 (a ↦ Int): {f}\n", .{app1});

    // --- Substitution s2 = [ b ↦ Bool ]
    var s2 = try Sub.one(b, tBool, alloc);

    // --- Compose substitutions: s = s2 ∘ s1
    // Meaning: first apply s1, then s2
    var s = try s2.compose(&s1, alloc);

    std.debug.print("Composed substitution {f}:\n", .{s});

    // --- Apply composed substitution to original type
    const app2 = try Type.apply(&app, &s, alloc);

    std.debug.print("After applying composed substitution: {f}\n", .{app2});

    // --- Sanity check: unused variable
    std.debug.print(
        "Contains c? {any}\n",
        .{s.contains(c)},
    );
}
