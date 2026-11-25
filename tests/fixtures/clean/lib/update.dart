// decoy: an announcement written in the admin panel, not an error
UpdateInfo parse(Map<String, Object?> d) =>
    UpdateInfo(message: d['message'] as String?);
