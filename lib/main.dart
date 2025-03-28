import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'repertoire_page.dart';

void main() async {
  //var appDatabase = db.AppDatabase();
  //dataAccess = DataAccess(appDatabase);
  //await dataAccess.setUser("pcaston2");
  //explorer = await RepertoireExplorer.create(dataAccess);
  runApp(MaterialApp(home: const MainMenu(title: "Repertoire Forge")));
}


class MainMenu extends StatefulWidget {
  const MainMenu({super.key, required this.title});

  final String title;

  @override
  State<MainMenu> createState() => _MainMenuState();
}

class _MainMenuState extends State<MainMenu> {
  @override
  Widget build(BuildContext context) {
    var repertoire = const RepertoirePage();
    return Scaffold(
      appBar: AppBar(title: const Text('Repertoire Forge')),
      drawer: Drawer(
          child: ListView(
            children: const [
              Text("Derp."),
            ],
          )),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          TextButton(
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => repertoire));
            },
            child: const Text("Let's do this"),
          )
        ],
      ),
    );
  }
}
