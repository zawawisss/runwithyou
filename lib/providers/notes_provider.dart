import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/note.dart';
import '../services/hive_service.dart';

class NotesNotifier extends Notifier<List<NoteModel>> {
  @override
  List<NoteModel> build() {
    return HiveService.getNotes();
  }

  Future<void> addNote(String content, int colorIndex) async {
    final note = NoteModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: content,
      colorIndex: colorIndex,
      date: DateTime.now(),
    );
    state = [...state, note];
    await HiveService.saveNote(note);
  }

  Future<void> editNote(String id, String content, int colorIndex) async {
    state = state.map((n) {
      if (n.id == id) {
        final updated = n.copyWith(content: content, colorIndex: colorIndex);
        HiveService.saveNote(updated);
        return updated;
      }
      return n;
    }).toList();
  }

  Future<void> deleteNote(String id) async {
    state = state.where((n) => n.id != id).toList();
    await HiveService.deleteNote(id);
  }
}

final notesProvider = NotifierProvider<NotesNotifier, List<NoteModel>>(NotesNotifier.new);
