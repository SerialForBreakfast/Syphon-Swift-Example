import Cocoa
import AVFoundation

class ViewController: NSViewController {
    
    var displayTimer: Timer?
    var context: NSOpenGLContext?
    
    var player: AVPlayer?
    var videoOutput: AVPlayerItemVideoOutput!
    var texture = GLuint()
    var size = NSSize(width: 512, height: 512)
    var syphonServer: SyphonServer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        displayTimer = Timer.scheduledTimer(timeInterval: 1 / 60, target: self, selector: #selector(screenRefresh), userInfo: nil, repeats: true)
        
        let contextAttributes: [NSOpenGLPixelFormatAttribute] = [
            NSOpenGLPixelFormatAttribute(NSOpenGLPFADoubleBuffer),
            NSOpenGLPixelFormatAttribute(NSOpenGLPFAColorSize), NSOpenGLPixelFormatAttribute(32),
            NSOpenGLPixelFormatAttribute(0)
        ]
        
        context = NSOpenGLContext(format: NSOpenGLPixelFormat(attributes: contextAttributes)!, share: nil)
        context?.makeCurrentContext()
        
        if texture == 0 { glGenTextures(1, &texture) }
        
        syphonServer = SyphonServer(name: "Video", context: context!.cglContextObj, options: nil)
        
        player = AVPlayer(url: Bundle.main.url(forResource: "video", withExtension: "mov")!)
        
        let bufferAttributes: [String: Any] = [
            String(kCVPixelBufferPixelFormatTypeKey): Int(kCVPixelFormatType_32BGRA),
            String(kCVPixelBufferIOSurfacePropertiesKey): [String: AnyObject](),
            String(kCVPixelBufferOpenGLCompatibilityKey): true
        ]
        
        videoOutput = AVPlayerItemVideoOutput(pixelBufferAttributes: bufferAttributes)
        videoOutput.suppressesPlayerRendering = true
        player?.currentItem?.add(videoOutput)
        
        player?.play()
    }
    
    func screenRefresh() {
        let itemTime = videoOutput.itemTime(forHostTime: CACurrentMediaTime())
        if videoOutput.hasNewPixelBuffer(forItemTime: itemTime) {
            if let pixelBuffer = videoOutput.copyPixelBuffer(forItemTime: itemTime, itemTimeForDisplay: nil) {
                if let surface = CVPixelBufferGetIOSurface(pixelBuffer)?.takeUnretainedValue() {
                    
                    size = NSSize(width: IOSurfaceGetWidth(surface), height: IOSurfaceGetHeight(surface))
                    
                    context?.makeCurrentContext()
                    
                    glBindTexture(GLenum(GL_TEXTURE_RECTANGLE_EXT), texture)
                    CGLTexImageIOSurface2D(context!.cglContextObj!, GLenum(GL_TEXTURE_RECTANGLE_EXT), GLenum(GL_RGBA), GLsizei(size.width), GLsizei(size.height), GLenum(GL_BGRA), GLenum(GL_UNSIGNED_INT_8_8_8_8_REV), surface, 0)
                }
            }
        }
        
        syphonServer?.publishFrameTexture(texture, textureTarget: GLenum(GL_TEXTURE_RECTANGLE_EXT), imageRegion: NSRect(origin: CGPoint(x: 0, y: 0), size: size), textureDimensions: size, flipped: true)
    }
    
    @IBAction func rewind(_ sender: AnyObject) {
        player?.seek(to: kCMTimeZero)
        player?.play()
    }
}
