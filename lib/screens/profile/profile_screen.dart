import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:myridedriverapp/config/route.dart';
import 'package:myridedriverapp/config/utils/constants.dart';
import 'package:myridedriverapp/controllers/profile_controller.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
      Get.find<ProfileController>().fetchProfile();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF3F4F6),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// Top Bar
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.white,
                    child: GestureDetector(
                      onTap: () {
                        Get.back();
                      },
                      child: Icon(Icons.close, color: Colors.black),
                    ),
                  ),
                  const Text(
                    "Profile",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 36),
                ],
              ),

              const SizedBox(height: 20),

              
              GetBuilder<ProfileController>(
                builder: (controller) {

                  print('images testing  ${controller.profileimagee}');
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Stack(
                          children: [
                            CircleAvatar(
                              radius: 34,
                              backgroundImage:
                                  (controller.profileimagee != null &&
                                      controller.profileimagee!.isNotEmpty)
                                  ? NetworkImage( ApiConstants.imageurl + controller.profileimagee!)
                                  : const NetworkImage(
                                      "https://cdn-icons-png.flaticon.com/512/9187/9187604.png",
                                    ),
                            ),

                            Positioned(
                              bottom: 2,
                              right: 2,
                              child: Container(
                                height: 14,
                                width: 14,
                                decoration: const BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(width: 12),

                        Expanded(
                          child: Text(
                            controller.userName ?? "No Name",
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),

                        InkWell(
                          onTap: () {
                            Get.toNamed(
                              RouteHelper.geteditProfileScreenScreen(),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xffF3F4F6),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              "Public Profile",
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

           
           
              // const SizedBox(height: 25),

              // /// Rides Header
              // Row(
              //   mainAxisAlignment: MainAxisAlignment.spaceBetween,
              //   children: [
              //     Text(
              //       "Rides",
              //       style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              //     ),
              //     InkWell(
              //       onTap: () {
              //         Get.toNamed(RouteHelper.getRideDetailsScreen());
              //       },
              //       child: Text(
              //         "View Details",
              //         style: TextStyle(
              //           color: Colors.blue,
              //           fontWeight: FontWeight.w500,
              //         ),
              //       ),
              //     ),
              //   ],
              // ),

              const SizedBox(height: 15),

              // /// Grid Stats
              // GridView.count(
              //   crossAxisCount: 2,
              //   crossAxisSpacing: 12,
              //   mainAxisSpacing: 12,
              //   shrinkWrap: true,
              //   physics: const NeverScrollableScrollPhysics(),
              //   childAspectRatio: 1.2,
              //   children: const [
              //     StatCard(
              //       title: "73%",
              //       subtitle: "Acceptance Rate",
              //       tag: "My Ride Pro",
              //     ),
              //     StatCard(
              //       title: "4.89 ⭐",
              //       subtitle: "Acceptance Rate",
              //       tag: "My Ride Pro",
              //     ),
              //     StatCard(
              //       title: "1%",
              //       subtitle: "Cancellation rate",
              //       tag: "My Ride Pro",
              //     ),
              //     StatCard(title: "98", subtitle: "Driving Score"),
              //   ],
              // ),

              // const SizedBox(height: 25),

              // const Text(
              //   "Lifetime highlights",
              //   style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              // ),

              // const SizedBox(height: 15),

              // Row(
              //   children: [
              //     Expanded(
              //       child: HighlightCard(
              //         title: "1358",
              //         subtitle: "Total Trips",
              //         image:
              //             "https://cdn-icons-png.flaticon.com/512/743/743131.png",
              //       ),
              //     ),
              //     const SizedBox(width: 12),
              //     Expanded(
              //       child: HighlightCard(
              //         title: "1 y 3 mo",
              //         subtitle: "Journey with Veyo",
              //         image:
              //             "https://cdn-icons-png.flaticon.com/512/992/992700.png",
              //       ),
              //     ),
              
              
              //   ],
              // ),
            ],
          ),
        ),
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? tag;

  const StatCard({
    super.key,
    required this.title,
    required this.subtitle,
    this.tag,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(subtitle, style: const TextStyle(color: Colors.grey)),
          const Spacer(),
          if (tag != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xffE6F4EA),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                tag!,
                style: const TextStyle(fontSize: 10, color: Colors.green),
              ),
            ),
        ],
      ),
    );
  }
}

class HighlightCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String image;

  const HighlightCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.image,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(subtitle, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.bottomRight,
            child: Image.network(image, height: 60),
          ),
        ],
      ),
    );
  }
}
