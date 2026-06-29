class UserPermissions {
  final bool canManageStaff;
  final bool canManageMenu;
  final bool canManageTables;
  final bool canViewRevenue;
  final bool canManageReservations;
  final bool canViewSettings;

  // MARK THE CONSTRUCTOR AS 'const'
  const UserPermissions({
    this.canManageStaff = false,
    this.canManageMenu = false,
    this.canManageTables = false,
    this.canViewRevenue = false,
    this.canManageReservations = false,
    this.canViewSettings = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'canManageStaff': canManageStaff,
      'canManageMenu': canManageMenu,
      'canManageTables': canManageTables,
      'canViewRevenue': canViewRevenue,
      'canManageReservations': canManageReservations,
      'canViewSettings': canViewSettings,
    };
  }

  factory UserPermissions.fromMap(Map<String, dynamic> map) {
    return UserPermissions(
      canManageStaff: map['canManageStaff'] ?? map['can_manage_staff'] ?? false,
      canManageMenu: map['canManageMenu'] ?? map['can_manage_menu'] ?? false,
      canManageTables: map['canManageTables'] ?? map['can_manage_tables'] ?? false,
      canViewRevenue: map['canViewRevenue'] ?? map['can_view_revenue'] ?? false,
      canManageReservations: map['canManageReservations'] ?? map['can_manage_reservations'] ?? false,
      canViewSettings: map['canViewSettings'] ?? map['can_view_settings'] ?? false,
    );
  }

  // Helper to get all permissions (for Owners) - NOW a METHOD, not a getter
  static UserPermissions allPermissions() {
    return const UserPermissions(
      canManageStaff: true,
      canManageMenu: true,
      canManageTables: true,
      canViewRevenue: true,
      canManageReservations: true,
      canViewSettings: true,
    );
  }

  // Helper to get staff permissions (minimal) - NOW a METHOD
  static UserPermissions staffPermissions() {
    return const UserPermissions(
      canManageStaff: false,
      canManageMenu: false,
      canManageTables: false,
      canViewRevenue: false,
      canManageReservations: false,
      canViewSettings: false,
    );
  }
}