import 'package:image/image.dart' as img;

void main() {
  final image = img.Image(width: 100, height: 100);
  img.fill(image, color: img.ColorRgb8(50, 50, 50));
  
  final padded = img.Image(width: 200, height: 200);
  img.fill(padded, color: img.ColorRgba8(0, 0, 0, 0));
  
  img.compositeImage(padded, image, dstX: 50, dstY: 50);
  print("Success padding");
}
