import 'package:flutter/material.dart';

class DocumentCard extends StatelessWidget {
  final String title;
  final bool isApproved;

  const DocumentCard({
    super.key,
    required this.title,
    required this.isApproved,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final width = size.width;
    final height = size.height;

    return Container(
      margin: EdgeInsets.only(bottom: height * 0.02),
      padding: EdgeInsets.all(width * 0.04),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [

          /// Left
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [

                Text(
                  title,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600),
                ),

                const SizedBox(height: 6),

                Row(
                  children: [
                    Icon(
                      isApproved
                          ? Icons.check_circle
                          : Icons.pending,
                      color: isApproved
                          ? Colors.blue
                          : Colors.orange,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isApproved
                          ? "Approved"
                          : "Pending",
                      style: TextStyle(
                        color: isApproved
                            ? Colors.blue
                            : Colors.orange,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    )
                  ],
                ),

                const SizedBox(height: 10),

                Container(
                  padding:
                      const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xffEAEAEA),
                    borderRadius:
                        BorderRadius.circular(20),
                  ),
                  child: const Text(
                    "View All Documents",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          FontWeight.w500,
                    ),
                  ),
                )
              ],
            ),
          ),

          /// Right Image
          Image.asset(
            "assets/images/document.png",
            height: height * 0.08,
          )
        ],
      ),
    );
  }
}