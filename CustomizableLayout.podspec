Pod::Spec.new do |spec|
  spec.name         = "CustomizableLayout"
  spec.version      = "0.1.0"
  spec.summary      = "Wrapper to create UICollectionViewLayout"

  spec.description  = <<-DESC
  This Library is built to helps make UICollectionViewLayout creation easier.
  DESC

  spec.homepage     = "https://github.com/98prabowo/CustomizableLayout"
  spec.authors      = { "98prabowo" => "dimasprabowo98@icloud.com" }
  spec.source       = { :git => "https://github.com/98prabowo/CustomizableLayout.git", :tag => "#{spec.version}" }
  spec.license      = { :type => "MIT", :file => "LICENSE" }
    
  spec.swift_version = '5.7'
  spec.ios.deployment_target = "11.0"

  spec.source_files  = "Sources/CustomizableLayout/**/*.swift"
  
  spec.dependency 'Texture', '~> 3.1'
  spec.xcconfig = { 'ENABLE_BITCODE' => 'NO' }
end
