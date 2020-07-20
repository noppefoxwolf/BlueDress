import Metal
import CoreVideo

public struct YCbCrImageBufferConverter {
    private let textureCache: CVMetalTextureCache
    private let commandQueue: MTLCommandQueue
    private let pipelineState: MTLRenderPipelineState
    private let vertexBuffer: MTLBuffer
    private let texCoordBuffer: MTLBuffer
    
    public init() throws {
        let device = MTLCreateSystemDefaultDevice()!
        let metalLib = try device.makeModuleLibrary()
        textureCache = try .make(device: device)
        commandQueue = device.makeCommandQueue()!
        pipelineState = try device.makeRenderPipelineState(metalLib: metalLib)
        vertexBuffer = device.makeVertexBuffer()
        texCoordBuffer = device.makeTexureCoordBuffer()
    }
    
    public func convertToBGRA(imageBuffer: CVPixelBuffer) throws -> CVPixelBuffer {
        guard imageBuffer.is420YpCbCr8BiPlanarFullRange else { fatalError() }
        guard imageBuffer.planeCount == 2 else { fatalError() }
        
        try imageBuffer.lock()
        defer { _ = try? imageBuffer.unlock() }
        
        let yTexture = try CVMetalTexture.make(
            sourceImage: imageBuffer,
            planeIndex: 0,
            pixelFormat: .r8Unorm,
            textureCache: textureCache
        ).metalTexture!
        
        let cbcrTexture = try CVMetalTexture.make(
            sourceImage: imageBuffer,
            planeIndex: 1,
            pixelFormat: .rg8Unorm,
            textureCache: textureCache
        ).metalTexture!
        
        let outputPixelBuffer = try CVPixelBuffer.make(width: yTexture.width, height: yTexture.height)
        let outputTexture = try CVMetalTexture.make(
            sourceImage: outputPixelBuffer,
            pixelFormat: .bgra8Unorm,
            textureCache: textureCache
        ).metalTexture!
                
        let renderDesc = MTLRenderPassDescriptor()
        renderDesc.colorAttachments[0].texture = outputTexture
        renderDesc.colorAttachments[0].loadAction = .clear
        
        if let commandBuffer = commandQueue.makeCommandBuffer(),
           let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderDesc) {
          renderEncoder.setRenderPipelineState(pipelineState)
          renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
          renderEncoder.setVertexBuffer(texCoordBuffer, offset: 0, index: 1)
          renderEncoder.setFragmentTexture(yTexture, index: 0)
          renderEncoder.setFragmentTexture(cbcrTexture, index: 1)
          renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
          renderEncoder.endEncoding()
          commandBuffer.commit()
        }
        
        return outputPixelBuffer
    }
}
