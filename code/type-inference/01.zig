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

pub fn main() !void {
    // ------------------------------------------------------------------
    // KINDS
    // ------------------------------------------------------------------
    // Create the base kind star kind `*`.
    // This kind represents ordinary, fully applied types, for example:
    //     Int : *
    //     Char : *
    //     ()   : *
    var star = Kind{ .star = {} };
    const kstar = &star;

    // Create the kind `* -> *`.
    // This kind represents type constructors that take one type
    // and return a new type:
    //     []    : * -> *
    //     List  : * -> *
    //     Array : * -> *
    // Any type with kind `* -> *` cannot be used as a value-level type
    // until it is applied to an argument of kind `*`.
    var kfun_star_star = Kind{
        .kfun = .{ .left = kstar, .right = kstar },
    };

    const tUnit = Type.typecon("()", star);
    var tChar = Type.typecon("Char", star);
    var tInt = Type.typecon("Int", star);

    // Create a type variable `a : *`.
    // This represents an unknown type that must later unify
    // with some concrete type during inference.
    var tvA = Type.typevar(0, star);
    // List constructor: [] : * -> *
    var tList = Type.typecon("[]", kfun_star_star);

    // Arrow constructor for function types: (->) : * -> (* -> *)
    // The left kind is `*`, and the right is again a constructor kind.
    //
    // When applied twice as:
    //     (->) A B
    // we obtain the function type A -> B.
    var tArrow = Type.typecon("(->)", Kind{
        .kfun = .{ .left = kstar, .right = &kfun_star_star },
    });

    // Tuple constructor: (,) : * -> *
    // (for simplicity represented as binary tuple)
    const tTuple2 = Type.typecon("(,)", kfun_star_star);

    // Build the type `[a]` by applying the List constructor to `a`:
    //     TApp tList a
    var listA = Type.typeapp(&tList, &tvA);

    // Build `Int -> [a]`.
    //
    // Function types are expressed by applying the arrow constructor twice:
    //     (->) Int [a]
    //
    // First application: (->) Int
    var arrowInt = Type.typeapp(&tArrow, &tInt);

    // Second application: ((->) Int) [a]
    const fnType = Type.typeapp(&arrowInt, &listA);

    // Build a concrete list type `[Char]`.
    const listChar = Type.typeapp(&tList, &tChar);

    // ----- printing -----
    std.debug.print("tUnit    = {f}\n", .{tUnit});
    std.debug.print("tChar    = {f}\n", .{tChar});
    std.debug.print("tInt     = {f}\n", .{tInt});
    std.debug.print("tList    = {f}\n", .{tList});
    std.debug.print("tArrow   = {f}\n", .{tArrow});
    std.debug.print("tTuple2  = {f}\n\n", .{tTuple2});

    std.debug.print("Type Int -> [a] = {f}\n\n", .{fnType});
    std.debug.print("tString = {f}\n", .{listChar});
}
