import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:myridedriverapp/config/utils/colors.dart';
import 'package:myridedriverapp/config/utils/dimensions.dart';
import 'package:myridedriverapp/config/utils/style.dart';

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final Color backgroundColor;
  final Color textColor;
  final double borderRadius;

  const CustomButton({
    Key? key,
    required this.text,
    required this.onPressed,
    this.backgroundColor = Colors.blue,
    this.textColor = Colors.white,
    this.borderRadius = 30,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.06,
        width: double.infinity,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: textColor,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

////////////////////////////////////////////////////////////
/// SOCIAL BUTTON
////////////////////////////////////////////////////////////
class CustomSocialButton extends StatelessWidget {
  final String text;
  final String images;
  //final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;

  const CustomSocialButton({
    Key? key,
    required this.text,
    required this.images,
    required this.iconColor,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    log("Button: $text");

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        child: InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: onTap,
          child: Container(
            height: MediaQuery.of(context).size.height * 0.06,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: const Color(0xffE0E0E0), width: 1),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                /// Left Icon
                Align(
                  alignment: Alignment.centerLeft,
                  child: Image.asset(
                    images,
                    height: 15,

                    // color: ColorResources.blueeebutton,
                  ),
                  //Icon(icon, size: 22, color: iconColor),
                ),

                /// Center Text
                Text(
                  text,
                  style: PoppinsSemiBold.copyWith(
                    color: ColorResources.blackcolor11,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

////////////////////////////////////////////////////////////
/// PRIMARY BUTTON (BLUE)
////////////////////////////////////////////////////////////

class CustomPrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const CustomPrimaryButton({Key? key, required this.text, required this.onTap})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(30),
      onTap: onTap,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.06,
        width: double.infinity,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: ColorResources.blueeebutton,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Text(
          text,
          style: PoppinsSemiBold.copyWith(color: ColorResources.buttonColors),
        ),
      ),
    );
  }
}

////////////////////////////////////////////////////////////
/// SECONDARY BUTTON (GREY)
////////////////////////////////////////////////////////////

class CustomSecondaryButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const CustomSecondaryButton({
    Key? key,
    required this.text,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(Dimensions.spacingSize30),
      onTap: onTap,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.06,
        width: double.infinity,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: ColorResources.buttonColors,
          borderRadius: BorderRadius.circular(Dimensions.spacingSize30),
        ),
        child: Text(
          text,
          style: PoppinsSemiBold.copyWith(color: ColorResources.blueeebutton),
        ),
      ),
    );
  }
}

class CustomPrimaryDyanamicButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const CustomPrimaryDyanamicButton({
    Key? key,
    required this.text,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(Dimensions.spacingSize30),
      onTap: onTap,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.06,
        width: double.infinity,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: ColorResources.blueeebutton,
          borderRadius: BorderRadius.circular(Dimensions.spacingSize30),
        ),
        child: Text(
          text,
          style: PoppinsSemiBold.copyWith(color: ColorResources.buttonColors),
        ),
      ),
    );
  }
}

class CustomSecondaryDynamicButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const CustomSecondaryDynamicButton({
    Key? key,
    required this.text,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(Dimensions.spacingSize30),
      onTap: onTap,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.06,
        width: double.infinity,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: ColorResources.buttonColors,
          borderRadius: BorderRadius.circular(Dimensions.spacingSize30),
        ),
        child: Text(
          text,
          style: PoppinsSemiBold.copyWith(color: ColorResources.blueeebutton),
        ),
      ),
    );
  }
}

class CustomIconsButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  final IconData? icons;
  final Color? colors;

  const CustomIconsButton({
    Key? key,
    required this.text,
    required this.onTap,
    required this.icons,
    this.colors,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(Dimensions.spacingSize30),
      onTap: onTap,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.06,
        decoration: BoxDecoration(
          color: ColorResources.buttonColors,
          borderRadius: BorderRadius.circular(Dimensions.spacingSize30),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icons, color: ColorResources.blueeebutton),
            SizedBox(width: 8),
            Text(
              text,
              style: TextStyle(color: ColorResources.blueeebutton, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),

    );
  }
}

class CustomMessageButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  final IconData? icons;
  final Color? colors;

  const CustomMessageButton({
    Key? key,
    required this.text,
    required this.onTap,
    required this.icons,
    this.colors,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(Dimensions.spacingSize30),
      onTap: onTap,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.06,
        decoration: BoxDecoration(
          color: ColorResources.blueeebutton,
          borderRadius: BorderRadius.circular(Dimensions.spacingSize30),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icons, color: ColorResources.whiteColor),
            SizedBox(width: 8),
            Text(
              text,
              style: TextStyle(
                color: ColorResources.whiteColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}





class CustomButtonVerify extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;

  const CustomButtonVerify({
    Key? key,
    required this.text,
    required this.onPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: ColorResources.appColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Dimensions.spacingSize25),
          ),
        ),
        onPressed: onPressed,
        child: Text(
          text,
           style: PoppinsBold.copyWith(
                  color: ColorResources.whiteColor,
                ),
          // style:
          //  const TextStyle(
          //     fontSize: 16,
          //     fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}




class ErningButions extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
 final Color colors;
  final Color textColor;
 final bool valuess;

   ErningButions({Key? key, required this.text, required this.onTap, required this.colors, required this.valuess, required this.textColor})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(30),
      onTap: onTap,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.06,
        width: double.infinity,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color:colors,
          // ColorResources.blueeebutton,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Text(
          text,
          style: PoppinsSemiBold.copyWith(color:textColor),
        ),
      ),
    );
  }
}


//////////////////======================= Cancle  button ==================//////////////////////
class CustomCancleButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const CustomCancleButton({Key? key, required this.text, required this.onTap})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(30),
      onTap: onTap,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.06,
        width: double.infinity,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: ColorResources.redbuttoncolor,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Text(
          text,
          style: PoppinsSemiBold.copyWith(color: ColorResources.textColorRed),
        ),
      ),
    );
  }
}


//// =============== Resend Otp Button ==========================////////////////////

class CustomOtpButton extends StatelessWidget {
  final String text;
  final VoidCallback? onTap; // 👈 nullable
  final bool isLoading;

  const CustomOtpButton({
    Key? key,
    required this.text,
    required this.onTap,
    this.isLoading = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bool isEnabled = onTap != null;

    return InkWell(
      borderRadius: BorderRadius.circular(30),
      onTap: isEnabled ? onTap : null,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.06,
        width: double.infinity,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isEnabled
              ? ColorResources.blueeebutton
              : ColorResources.buttonColors,
          borderRadius: BorderRadius.circular(30),
        ),
        child: isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                text,
                style: PoppinsSemiBold.copyWith(
                  color: isEnabled
                      ? ColorResources.whiteColor
                      : ColorResources.blackcolor,
                ),
              ),
      ),
    );
  }
}


///////// ================= Disable =================== //////////////////


class CustomDisabledButton extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;
  final bool isEnabled;

  const CustomDisabledButton({
    Key? key,
    required this.text,
    required this.onTap,
    this.isEnabled = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(30),
      onTap: isEnabled ? onTap : null,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.06,
        width: double.infinity,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isEnabled
              ? ColorResources.redbuttoncolor
              : Colors.grey.shade400,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Text(
          text,
          style: PoppinsSemiBold.copyWith(
            color: isEnabled
                ? ColorResources.buttonColors
                : Colors.white70,
          ),
        ),
      ),
    );
  }
}