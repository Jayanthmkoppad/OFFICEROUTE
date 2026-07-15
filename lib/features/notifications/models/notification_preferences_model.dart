class NotificationPreferencesModel {
  final bool attendanceReminders;
  final bool visitAlerts;
  final bool managerAlerts;
  final bool localInAppNotifications;
  final bool fcmPlaceholdersEnabled;

  const NotificationPreferencesModel({
    required this.attendanceReminders,
    required this.visitAlerts,
    required this.managerAlerts,
    required this.localInAppNotifications,
    required this.fcmPlaceholdersEnabled,
  });

  factory NotificationPreferencesModel.defaults() {
    return const NotificationPreferencesModel(
      attendanceReminders: true,
      visitAlerts: true,
      managerAlerts: true,
      localInAppNotifications: true,
      fcmPlaceholdersEnabled: false,
    );
  }

  factory NotificationPreferencesModel.fromMap(Map<String, dynamic> map) {
    return NotificationPreferencesModel(
      attendanceReminders: map['attendanceReminders'] ?? true,
      visitAlerts: map['visitAlerts'] ?? true,
      managerAlerts: map['managerAlerts'] ?? true,
      localInAppNotifications: map['localInAppNotifications'] ?? true,
      fcmPlaceholdersEnabled: map['fcmPlaceholdersEnabled'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'attendanceReminders': attendanceReminders,
      'visitAlerts': visitAlerts,
      'managerAlerts': managerAlerts,
      'localInAppNotifications': localInAppNotifications,
      'fcmPlaceholdersEnabled': fcmPlaceholdersEnabled,
    };
  }

  NotificationPreferencesModel copyWith({
    bool? attendanceReminders,
    bool? visitAlerts,
    bool? managerAlerts,
    bool? localInAppNotifications,
    bool? fcmPlaceholdersEnabled,
  }) {
    return NotificationPreferencesModel(
      attendanceReminders: attendanceReminders ?? this.attendanceReminders,
      visitAlerts: visitAlerts ?? this.visitAlerts,
      managerAlerts: managerAlerts ?? this.managerAlerts,
      localInAppNotifications:
          localInAppNotifications ?? this.localInAppNotifications,
      fcmPlaceholdersEnabled:
          fcmPlaceholdersEnabled ?? this.fcmPlaceholdersEnabled,
    );
  }
}
