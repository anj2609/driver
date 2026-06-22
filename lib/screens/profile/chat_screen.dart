import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:myridedriverapp/config/utils/constants.dart';
import 'package:myridedriverapp/controllers/chat_controller.dart';
import 'package:myridedriverapp/model/acceptride_details_model.dart';
import 'package:myridedriverapp/model/trinpdetails_model.dart';
import 'package:myridedriverapp/widgets/custom_loader.dart';

class DriverChatScreen extends StatefulWidget {
  final bool isDriverScreen;
  final String? bookingId;
  final AcceptRideModel? acceptData;

  ///  final NewBookingNearByModel? trips;
  final TripDetailsModel? trips;
  const DriverChatScreen({
    Key? key,
    required this.isDriverScreen,
    this.bookingId,
    this.acceptData,
    this.trips,
  }) : super(key: key);

  @override
  State<DriverChatScreen> createState() => _DriverChatScreenState();
}

class _DriverChatScreenState extends State<DriverChatScreen> {
  final ChatController controller = Get.put(
    ChatController(chatRepo: Get.find()),
  );

  final TextEditingController messageController = TextEditingController();

  Timer? refreshTimer;
  bool hideQuickButtons = false;

  @override
  void initState() {
    super.initState();

    loadChats();

    /// AUTO REFRESH CHAT
    refreshTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      await loadChats();
    });
  }

  Future<void> loadChats() async {
    await controller.chatessagesList(context: context);

    if (Get.find<ChatController>().chatId != null) {
      await controller.messageRead(
        context: context,
        chatId: Get.find<ChatController>().chatId.toString(),
      );
    }

    controller.update();
  }

  @override
  void dispose() {
    refreshTimer?.cancel();
    messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () {
            Get.back();
          },
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
        ),

        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: Colors.grey.shade300,
              backgroundImage:
                  widget
                      .acceptData!
                      .data!
                      .customerInfo!
                      .profileImage!
                      .isNotEmpty
                  ? NetworkImage(
                      "${ApiConstants.imageurl}${widget.acceptData!.data!.customerInfo!.profileImage}",
                    )
                  : null,
              child:
                  widget.acceptData!.data!.customerInfo!.profileImage!.isEmpty
                  ? const Icon(Icons.person, color: Colors.white)
                  : null,
            ),

            const SizedBox(width: 12),

            Text(
              widget.acceptData!.data!.customerInfo!.name.toString(),
              style: const TextStyle(color: Colors.black),
            ),
          ],
        ),
      ),

      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text(
              "Keep your account safe - never share personal info in chat",
              style: TextStyle(fontSize: 11, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ),

          Expanded(
            child: GetBuilder<ChatController>(
              builder: (controller) {
                if (controller.isLoading) {
                  return Center(
                    child: PremiumBlurLoader(),

                    /// CircularProgressIndicator(),
                  );
                }

                if (controller.chatMessagesList.isEmpty) {
                  return const Center(child: Text("No Messages Found"));
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 12,
                  ),
                  itemCount: controller.chatMessagesList.length,
                  reverse: false,
                  itemBuilder: (context, index) {
                    var msg = controller.chatMessagesList[index];

                    bool isMe = msg.senderId.toString() == driverId.toString();

                    String dateTime = msg.createdAt ?? "";

                    String msgDate = "";
                    String msgTime = "";

                    if (dateTime.contains(" ")) {
                      msgDate = dateTime.split(" ").first;

                      if (dateTime.length >= 16) {
                        msgTime = dateTime.substring(11, 16);
                      }
                    }

                    bool showDate = false;

                    if (index == 0) {
                      showDate = true;
                    } else {
                      var prev = controller.chatMessagesList[index - 1];

                      String prevDate = (prev.createdAt ?? "").split(" ").first;

                      if (prevDate != msgDate) {
                        showDate = true;
                      }
                    }

                    bool firstBubble = false;
                    bool lastBubble = false;

                    if (index == 0) {
                      firstBubble = true;
                    } else {
                      var prev = controller.chatMessagesList[index - 1];

                      if (prev.senderId != msg.senderId) {
                        firstBubble = true;
                      }
                    }

                    if (index == controller.chatMessagesList.length - 1) {
                      lastBubble = true;
                    } else {
                      var next = controller.chatMessagesList[index + 1];

                      if (next.senderId != msg.senderId) {
                        lastBubble = true;
                      }
                    }

                    return Column(
                      children: [
                        if (showDate)
                          Center(
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 10),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xff1F2C34),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                msgDate ==
                                        DateTime.now()
                                            .toString()
                                            .split(" ")
                                            .first
                                    ? "Today"
                                    : msgDate,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),

                        Align(
                          alignment: isMe
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            margin: EdgeInsets.only(
                              top: firstBubble ? 8 : 2,
                              bottom: lastBubble ? 8 : 2,
                            ),
                            padding: const EdgeInsets.fromLTRB(14, 10, 10, 6),
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width * .75,
                            ),
                            decoration: BoxDecoration(
                              color: isMe
                                  ? const Color(0xff005C4B)
                                  : const Color(0xff202C33),
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(12),
                                topRight: const Radius.circular(12),
                                bottomLeft: Radius.circular(
                                  isMe ? 12 : (lastBubble ? 2 : 12),
                                ),
                                bottomRight: Radius.circular(
                                  isMe ? (lastBubble ? 2 : 12) : 12,
                                ),
                              ),
                            ),

                            child: IntrinsicWidth(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Flexible(
                                    child: Text(
                                      msg.message ?? "",
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 17,
                                      ),
                                    ),
                                  ),

                                  const SizedBox(width: 10),

                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        msgTime,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.white70,
                                        ),
                                      ),

                                      if (isMe)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            left: 4,
                                          ),
                                          child: Icon(
                                            controller.messagesSeen
                                                ? Icons.done_all
                                                : Icons.done,
                                            size: 15,
                                            color: controller.messagesSeen
                                                ? Colors.blueAccent
                                                : Colors.white70,
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),

          if (widget.isDriverScreen && !hideQuickButtons)
            Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  quickButton("I've arrived"),
                  quickButton("OK, got it"),
                  quickButton("I'm on my way"),
                ],
              ),
            ),

          /// SEND BOX
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: TextField(
                      controller: messageController,
                      decoration: const InputDecoration(
                        hintText: "Write messages...",
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                GestureDetector(
                  onTap: () async {
                    if (messageController.text.trim().isEmpty) {
                      return;
                    }

                    final messageText = messageController.text.trim();

                    messageController.clear();

                    await controller.sendChatMessages(
                      context: context,
                      bookingId: widget.acceptData!.data!.bookingId.toString(),
                      driverId: driverId.toString(),
                      customerId: widget
                          .acceptData!
                          .data!
                          .customerInfo!
                          .customer
                          .toString(),
                      message: messageText,
                    );

                    /// REFRESH CHAT
                    await loadChats();
                  },
                  child: const CircleAvatar(
                    backgroundColor: Colors.blue,
                    child: Icon(Icons.send, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget quickButton(String text) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () async {
          setState(() {
            hideQuickButtons = true;
          });

          await controller.sendChatMessages(
            context: context,
            bookingId: widget.acceptData!.data!.bookingId.toString(),
            driverId: driverId.toString(),
            customerId: widget.acceptData!.data!.customerInfo!.customer
                .toString(),
            message: text,
          );

          await loadChats();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade400),
          ),
          child: Text(text),
        ),
      ),
    );
  }
}
