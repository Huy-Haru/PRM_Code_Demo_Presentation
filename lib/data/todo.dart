class Todo {
  const Todo({this.id, required this.title, this.done = false});

  final int? id;
  final String title;
  final bool done;

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'title': title,
        'done': done ? 1 : 0,
      };

  factory Todo.fromMap(Map<String, Object?> row) => Todo(
        id: row['id'] as int?,
        title: row['title'] as String,
        done: (row['done'] as int) == 1,
      );
}
