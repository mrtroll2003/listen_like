import 'package:flutter/material.dart';

double scaleWidth(BuildContext context, double width, {double designWidth = 1920}) {
  double screenWidth = MediaQuery.of(context).size.width;
  return (width / designWidth) * screenWidth;
}
double scaleHeight(BuildContext context, double height, {double designHeight = 1080}) {
  double screenHeight = MediaQuery.of(context).size.height;
  return (height / designHeight) * screenHeight;
}