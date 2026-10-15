/// The signed-in user. Mirrors the web app's `novaUser` session object.
class AppUser {
  const AppUser({required this.name, required this.email, this.planId});

  final String name;
  final String email;

  /// Selected subscription plan id, null until the user picks one.
  final String? planId;

  AppUser copyWith({String? name, String? planId}) => AppUser(
        name: name ?? this.name,
        email: email,
        planId: planId ?? this.planId,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'email': email,
        if (planId != null) 'plan': planId,
      };

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        name: json['name'] as String? ?? '',
        email: json['email'] as String? ?? '',
        planId: json['plan'] as String?,
      );
}
