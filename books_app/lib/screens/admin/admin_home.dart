import 'package:flutter/material.dart';
import '../../core/supabase_client.dart';
import '../auth/login_screen.dart';

class AdminHome extends StatefulWidget {
  const AdminHome({super.key});

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  // Fungsi Logout
  Future<void> _logout() async {
    await supabase.auth.signOut();
    if (!mounted) return;
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  // Fungsi hapus buku
  Future<void> _deleteBook(int id) async {
    try {
      await supabase.from('books').delete().eq('id', id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Buku berhasil dihapus')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error hapus: $e')),
        );
      }
    }
  }

  // Fungsi gabungan: Create & Edit (Update)
  Future<void> _showBookForm(BuildContext context, {Map<String, dynamic>? book}) async {
    final titleController = TextEditingController();
    final authorController = TextEditingController();
    final stockController = TextEditingController(); 
    // Kalau Mode Edit, isi text field dengan data lama
    if (book != null) {
      titleController.text = book['title'];
      authorController.text = book['author'];
      stockController.text = book['stock'].toString(); 
    }

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(book == null ? 'Tambah Buku Baru' : 'Edit Buku'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Judul Buku'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: authorController,
              decoration: const InputDecoration(labelText: 'Penulis'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: stockController,
              decoration: const InputDecoration(labelText: 'Stok'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              final title = titleController.text.trim();
              final author = authorController.text.trim();
              final stockStr = stockController.text.trim();
              
              final stock = int.tryParse(stockStr) ?? 1;

              if (title.isEmpty || author.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Judul dan Penulis harus diisi!')));
                return;
              }

              Navigator.pop(ctx); 

              try {
                if (book == null) {
                  // --- LOGIKA TAMBAH (CREATE) ---
                  await supabase.from('books').insert({
                    'title': title,
                    'author': author,
                    'stock': stock, // Masukin stok dinamis
                  });
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Buku berhasil ditambahkan')));
                  }
                } else {
                  // --- LOGIKA EDIT (UPDATE) ---
                  await supabase
                      .from('books')
                      .update({
                        'title': title,
                        'author': author,
                        'stock': stock, // Update stok juga
                      })
                      .eq('id', book['id']);
                  
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Buku berhasil diupdate')));
                  }
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Terjadi kesalahan: $e')));
                }
              }
            },
            child: Text(book == null ? 'Simpan' : 'Update'),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Stream data buku
    final booksStream = supabase
        .from('books')
        .stream(primaryKey: ['id']).order('id', ascending: true);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.redAccent,
        actions: [
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout, color: Colors.white),
          )
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: booksStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Belum ada buku. Tambahin dong bray!'));
          }

          final books = snapshot.data!;

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: books.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (context, index) {
              final book = books[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.redAccent.shade100,
                  child: Text(book['title'][0].toUpperCase()),
                ),
                title: Text(
                  book['title'],
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                // Menampilkan stok di subtitle
                subtitle: Text('Penulis: ${book['author']} | Stok: ${book['stock']}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () => _showBookForm(context, book: book),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Hapus Buku?'),
                            content: Text('Yakin mau hapus "${book['title']}"?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  _deleteBook(book['id']);
                                }, 
                                child: const Text('Hapus', style: TextStyle(color: Colors.red))
                              ),
                            ],
                          )
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.redAccent,
        onPressed: () => _showBookForm(context),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}