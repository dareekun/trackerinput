class User {
  final int? id;
  final String email;
  final String passwordHash;
  final String salt;
  final String? recoveryQuestion;
  final String? recoveryAnswerHash;
  final String? recoverySalt;
  final String? createdAt;

  User({
    this.id,
    required this.email,
    required this.passwordHash,
    required this.salt,
    this.recoveryQuestion,
    this.recoveryAnswerHash,
    this.recoverySalt,
    this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'email': email,
        'password_hash': passwordHash,
        'salt': salt,
        'recovery_question': recoveryQuestion,
        'recovery_answer_hash': recoveryAnswerHash,
        'recovery_salt': recoverySalt,
        'created_at': createdAt,
      };

  factory User.fromMap(Map<String, dynamic> map) => User(
        id: map['id'] as int?,
        email: map['email'] as String,
        passwordHash: map['password_hash'] as String,
        salt: map['salt'] as String,
        recoveryQuestion: map['recovery_question'] as String?,
        recoveryAnswerHash: map['recovery_answer_hash'] as String?,
        recoverySalt: map['recovery_salt'] as String?,
        createdAt: map['created_at'] as String?,
      );
}
