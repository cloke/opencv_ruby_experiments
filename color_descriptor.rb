# This script is heavily inspired by a great python tutorial on the same subject:
# http://www.pyimagesearch.com/2014/12/01/complete-guide-building-image-search-engine-python-opencv/

require 'opencv'
require 'byebug'
require 'csv'

include OpenCV

class ColorDescriptor
  def initialize(bins = [8, 12, 3])
    @bins = bins
  end

  def bins
    @bins
  end

  def describe(image_path)
    # convert the image to the HSV color space and initialize
    # the features used to quantify the image

    image = IplImage.load(image_path, 3).RGB2HSV
    features = []

    # grab the dimensions and compute the center of the image
    (h, w) = image.dims
    (cX, cY) = [(w * 0.5).to_i, (h * 0.5).to_i]

    # divide the image into four rectangles/segments (top-left,
    # top-right, bottom-right, bottom-left)
    segments = [[0, cX, 0, cY], [cX, w, 0, cY], [cX, w, cY, h], [0, cX, cY, h]]

    # construct an elliptical mask representing the center of the image
    (axesX, axesY) = [(w * 0.75).to_i / 2, (h * 0.75).to_i / 2]
    ellipMask = CvMat.new(h, w, :cv32f, 3)
                  .ellipse(CvPoint.new(cX, cY), CvSize.new(axesX, axesY), 0, 0, 360, {color: CvColor::White, thickness: -1})

    # loop over the segments
    for (startX, endX, startY, endY) in segments
      # construct a mask for each corner of the image, subtracting
      # the elliptical center from it
      cornerMask = image.rectangle(CvPoint.new(startX, startY), CvPoint.new(endX, endY), { color: CvColor::White, thickness: -1})
                     .sub(image)
                     .sub(ellipMask)
      
      # extract a color histogram from the image, then update the
      # feature vector
      features << histogram(cornerMask)
    end

    ellipIMask = image.ellipse(CvPoint.new(cX, cY), CvSize.new(axesX, axesY), 0, 0, 360, {color: CvColor::White, thickness: -1})
                   .sub(image)
    features << histogram(ellipIMask)
    return features.flatten
  end

  def histogram(image, mask = nil)
    # extract a 3D color histogram from the masked region of the
    # image, using the supplied number of bins per channel; then
    # normalize the histogram
    b, g, r = image.split

    hist = CvHistogram.new(bins.size, bins, CV_HIST_ARRAY, [[0, 180], [0, 256], [0, 256]], true ).calc_hist [b, g, r], false, mask
    hist.normalize!(10000)
    vals = []
    i = 0
    
    while i < bins.inject(:*)
      vals << hist[i].to_s
      i += 1
    end
    
    return vals
  end
end

def chi2(histA, histB, eps = 1e-10 )
  d = []
  for (a, b) in histA.zip histB
    a = a.to_f
    b = b.to_f
    d << ((a - b) ** 2) / (a + b + eps)
  end
  0.5 * d.inject(:+)
end

def index dir_path, type = '.png'
  CSV.open('my_index.csv', 'w') do |csv|
    Dir["#{dir_path}/**/*#{type}"].each do |e|
      csv << ColorDescriptor.new.describe(e).unshift(e)
    end
  end
end


def search path, max_results = -1
  features = ColorDescriptor.new.describe(path)
  results = []
  CSV.foreach('my_index.csv') do |row|
    id = row.shift
    results << [chi2(features, row), id]
  end
  
  results.sort_by!{|k|k[0]}
  results[0..max_results.to_i]
end

case ARGV[0]
when 'index'
  index ARGV[1], ARGV[2] || '.png'

when 'search'
  p search ARGV[1], ARGV[2] || -1
end

