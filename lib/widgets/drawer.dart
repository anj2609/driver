import 'package:flutter/material.dart';
import 'package:myridedriverapp/config/utils/colors.dart';

/// ✅ Custom Drawer
class CustomDrawer extends StatelessWidget {
  const CustomDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            color: ColorResources.appColor,
            child: const SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.person, size: 35),
                  ),
                  SizedBox(height: 10),
                  Text(
                    "Driver Name",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    "driver@email.com",
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
          ),

          /// Drawer Items
          drawerItem(Icons.home, "Home"),
          drawerItem(Icons.history, "Ride History"),
          drawerItem(Icons.account_balance_wallet, "Wallet"),
          drawerItem(Icons.settings, "Settings"),
          drawerItem(Icons.logout, "Logout"),
        ],
      ),
    );
  }

  Widget drawerItem(IconData icon, String title) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      onTap: () {
        if (title == "Home") {
        } else if (title == "Ride History") {}
        if (title == "Wallet") {}
        if (title == "Settings") {}
        if (title == "Logout") {}
      },
    );
  }
}
