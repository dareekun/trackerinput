class User {
  final int? id;
  final String name;
  final String username;
  final String passwordHash;
  final String salt;
  final String? recoveryQuestion;
  final String? recoveryAnswerHash;
  final String? recoverySalt;
  final String? createdAt;

  User({
    this.id,
    required this.name,
    required this.username,
    required this.passwordHash,
    required this.salt,
    this.recoveryQuestion,
    this.recoveryAnswerHash,
    this.recoverySalt,
    this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'username': username,
        'password_hash': passwordHash,
        'salt': salt,
        'recovery_question': recoveryQuestion,
        'recovery_answer_hash': recoveryAnswerHash,
        'recovery_salt': recoverySalt,
        'created_at': createdAt,
      };

  factory User.fromMap(Map<String, dynamic> map) => User(
        id: map['id'] as int?,
        name: map['name'] as String,
        username: map['username'] as String,
        passwordHash: map['password_hash'] as String,
        salt: map['salt'] as String,
        recoveryQuestion: map['recovery_question'] as String?,
        recoveryAnswerHash: map['recovery_answer_hash'] as String?,
        recoverySalt: map['recovery_salt'] as String?,
        createdAt: map['created_at'] as String?,
      );
}
