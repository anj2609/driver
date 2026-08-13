import 'package:flutter/material.dart';

const opensansSemiBold = TextStyle(
  fontFamily: "OpenSans",
  fontWeight: FontWeight.w600,
);

const opensansMedium = TextStyle(
  fontFamily: 'OpenSans',
  fontWeight: FontWeight.w500,
);

const opensansBold = TextStyle(
  fontFamily: 'OpenSans',
  fontWeight: FontWeight.w700,
);

final opensansRegular = TextStyle(
  fontFamily: 'OpenSans',
  fontWeight: FontWeight.w400,
);

// Not lowerCamelCase on purpose — every call site across the app (100+
// usages) references these by this exact capitalization. A prior pass
// renamed just these declarations to satisfy the constant-naming lint
// without updating any of the usages, which broke the build project-wide.
// Restoring the original names here (rather than renaming every usage)
// is the minimal fix.
final PoppinsReguler = TextStyle(
  fontFamily: 'Poppins',
  fontWeight: FontWeight.w300,
);

final PoppinsSemiBold = TextStyle(
  fontFamily: 'Poppins',
  fontWeight: FontWeight.w600,
);
final PoppinsBold = TextStyle(
  fontFamily: 'Poppins',
  fontWeight: FontWeight.w700,
);
final PoppinsMedium = TextStyle(
  fontFamily: 'Poppins',
  fontWeight: FontWeight.w400,
);
final PoppinsExtrabold = TextStyle(
  fontFamily: 'Poppins',
  fontWeight: FontWeight.w800,
);