pub const Kind = union(enum) {
    star: void, // simplest option
    kfun: struct { left: *Kind, right: *Kind },

    pub fn isStar(a: Kind) bool {
        return switch (a) {
            .star => true,
            else => false,
        };
    }

    pub fn eql(a: *const Kind, b: *const Kind) bool {
        return switch (a.*) {
            .star => b.isStar(),
            .kfun => |a_fun| {
                const b_fun = b.kfun;
                return a_fun.left.eql(b_fun.left) and
                    a_fun.right.eql(b_fun.right);
            },
        };
    }
};

pub const Id = u32;
pub const TyVar = struct {
    id: Id,
    kind: Kind,

    pub fn getKind(self: TyVar) Kind {
        return self.kind;
    }

    pub fn eql(self: TyVar, other: TyVar) bool {
        if (self.id == other.id and Kind.eql(&self.kind, &other.kind)) {
            return true;
        }
        return false;
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
    tapp: struct { left: *Type, right: *Type },
    tgen: GenId,

    pub fn typevar(id: Id, kind: Kind) Type {
        return .{ .tvar = TyVar{ .id = id, .kind = kind } };
    }

    pub fn typecon(name: []const u8, kind: Kind) Type {
        return .{ .tcon = TyCon{ .name = name, .kind = kind } };
    }

    pub fn typeapp(left: *Type, right: *Type) Type {
        return .{ .tapp = .{ .left = left, .right = right } };
    }

    pub fn typegen(id: GenId) Type {
        return .{ .tgen = id };
    }

    pub fn getKind(self: Type) Kind {
        return switch (self) {
            .tvar => |s| s.getKind(),
            .tcon => |c| c.getKind(),
            .tgen => unreachable, // will be described later
            .tapp => |a| blk: {
                const k = a.left.getKind();
                switch (k) {
                    .kfun => |f| break :blk f.right.*,
                    else => unreachable,
                }
            },
        };
    }
};

const std = @import("std");

fn printKind(k: Kind) void {
    switch (k) {
        .star => std.debug.print("*", .{}),
        .kfun => |f| {
            std.debug.print("(", .{});
            printKind(f.left.*);
            std.debug.print(" -> ", .{});
            printKind(f.right.*);
            std.debug.print(")", .{});
        },
    }
}

fn printType(t: *const Type) void {
    switch (t.*) {
        .tvar => |v| std.debug.print("TVar({d})", .{v.id}),
        .tcon => |c| std.debug.print("{s}", .{c.name}),
        .tgen => |g| std.debug.print("TGen({d})", .{g}),
        .tapp => |a| {
            std.debug.print("(", .{});
            printType(a.left);
            std.debug.print(" ", .{});
            printType(a.right);
            std.debug.print(")", .{});
        },
    }
}

pub fn main() !void {
    var star = Kind{ .star = {} };
    // * kind (star)
    const kstar = &star;
    // * -> * kind
    var kfun_star_star = Kind{
        .kfun = .{ .left = kstar, .right = kstar },
    };

    var tUnit = Type.typecon("()", star);
    var tChar = Type.typecon("Char", star);
    var tInt = Type.typecon("Int", star);

    // constructors
    var tList = Type.typecon("[]", kfun_star_star);
    var tArrow = Type.typecon("(->)", Kind{
        .kfun = .{ .left = kstar, .right = &kfun_star_star },
    });
    var tTuple2 = Type.typecon("(,)", kfun_star_star);

    // ----- type variable `a` -----
    var tvA = Type.typevar(0, star);

    // [a] == TApp tList a
    var listA = Type.typeapp(&tList, &tvA);

    // Int -> [a]
    // TApp (TApp tArrow tInt) [a]
    var arrowInt = Type.typeapp(&tArrow, &tInt);
    var fnType = Type.typeapp(&arrowInt, &listA);

    // tString = [Char]
    var listChar = Type.typeapp(&tList, &tChar);

    // ----- printing -----
    std.debug.print("tUnit = ", .{});
    printType(&tUnit);
    std.debug.print("\n", .{});
    std.debug.print("tChar = ", .{});
    printType(&tChar);
    std.debug.print("\n", .{});
    std.debug.print("tInt = ", .{});
    printType(&tInt);
    std.debug.print("\n", .{});
    std.debug.print("tList = ", .{});
    printType(&tList);
    std.debug.print("\n", .{});
    std.debug.print("tArrow = ", .{});
    printType(&tArrow);
    std.debug.print("\n", .{});
    std.debug.print("tTuple2 = ", .{});
    printType(&tTuple2);
    std.debug.print("\n\n", .{});

    std.debug.print("Type Int -> [a] = ", .{});
    printType(&fnType);
    std.debug.print("\n\n", .{});

    std.debug.print("tString = ", .{});
    printType(&listChar);
    std.debug.print("\n", .{});
}
