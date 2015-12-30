require 'opencv'
include OpenCV

if ARGV.length < 2
  puts "Usage: ruby #{__FILE__} source dest"
  exit
end

data = './haarcascade_mcs_righteye.xml'
detector = CvHaarClassifierCascade::load(data)
image = CvMat.load(ARGV[0])
detector.detect_objects(image).each do |region|
  color = CvColor::Blue
  image.rectangle! region.top_left, region.bottom_right, :color => color
end

image.save_image(ARGV[1])
window = GUI::Window.new('Face detection')
window.show(image)
GUI::wait_key

