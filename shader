var device = {};
device.shaders = [];

var canvas = document.getElementById('canvas'),gl, names = ["webgl", "experimental-webgl"];
for (i = 0; i < names.length; i++) {
    try {
        gl = canvas.getContext(names[i], {});
    } catch (e) { }
}
device.gl = gl;



function prepFrameBuffer(gl){

    var texture = genTexture(gl);

    gl.texImage2D(
        gl.TEXTURE_2D, 0, gl.RGBA,
        gl.drawingBufferWidth, gl.drawingBufferHeight,
        0, gl.RGBA, gl.UNSIGNED_BYTE, null
    );

    gl.bindTexture(gl.TEXTURE_2D, null);

    var fbo = gl.createFramebuffer();
    gl.bindFramebuffer(gl.FRAMEBUFFER, fbo);

    gl.framebufferTexture2D(
        gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0,
        gl.TEXTURE_2D, texture, 0
    );

    gl.bindFramebuffer(gl.FRAMEBUFFER, null);

    return {
        texture: texture,
        fbo: fbo
    };
}





//============================================

function createShader(gl, type, src) {
    var shader = gl.createShader(type);
    gl.shaderSource(shader, src);
    gl.compileShader(shader);
    return shader;
}

function createProgram(gl, vertexShader, fragmentShader) {
    var program = gl.createProgram();
    gl.attachShader(program, vertexShader);
    gl.attachShader(program, fragmentShader);
    return program;
}


const compileShader = (_definition,_shader) =>{
    _shader.ready = false;
    _shader.definition = _definition;
    _shader.vshader = createShader(gl, gl.VERTEX_SHADER, _definition.vshader);
    _shader.fshader = createShader(gl, gl.FRAGMENT_SHADER, _definition.fshader);
    _shader.program = createProgram(gl, _shader.vshader, _shader.fshader);
    return _shader;
};

const ShaderState = st => ({
    runState:x => {
        let [a,s] = st(x);
        device.shaders.push(s);
        return [a,s];
    },
     chain: (f) => ShaderState(s => {
        const [f,r] = st(x);
        return f(l).runState(r);
    }),
    withState: f => ShaderState(s => [f(...st(s)),s]),
    then:(f) => ShaderState(s => {
        const  [v,ss] = st(s);
        const  res = f(s);
        return res.runState ? res.runState(ss) : [res,ss]
    })
});

ShaderState.of = (x) => ShaderState(s => [x,s]);
//
// var shaderState = ShaderState.of('111').withState(compileShader);
//
// shaderState.then(linkShader);
//
// var shaderinfo =  shaderState.runState({});
//
// let [define,_shader] = shaderinfo;

const LOGERROR = (_shader) => {
    if (! gl.getShaderParameter(_shader.vshader, gl.COMPILE_STATUS)) {
        console.error("Failed to compile vertex shader:\n\n" + _shader.definition.vshader + "\n\n" + gl.getShaderInfoLog(_shader.vshader));
    }
    if (! gl.getShaderParameter(_shader.fshader, gl.COMPILE_STATUS)) {
        console.error("Failed to compile fragment shader:\n\n" + _shader.definition.fshader + "\n\n" + gl.getShaderInfoLog(_shader.fshader));
    }
    if (! gl.getProgramParameter(_shader.program, gl.LINK_STATUS)) {
        console.error("Failed to link shader program. Error: " + gl.getProgramInfoLog(_shader.program));
    }
}
const linkShader = (_shader) => {
    gl.linkProgram(_shader.program);
    LOGERROR(_shader);

    gl.deleteShader(_shader.vshader);
    gl.deleteShader(_shader.fshader);

    _shader.attributes = [];
    _shader.uniforms = [];
    _shader.samplers = [];

    _shader.ready = true;

    return ShaderState.of(_shader);
}



const callcc = lambda => cps => lambda(x => cps(x));

const loadimg = src => k => {
    var image = new Image();
    image.src = src;
    image.onload = () => {
        k(image);
    }
};
var imgcallcc = callcc(loadimg('./textures/emiss_2.jpg'));



imgcallcc(image => {

    ShaderState.of({
        vshader: `
    attribute vec2 aUv;
    attribute vec4 aPosition;
    varying vec2 vUv;
    uniform mat4 mWorld;
    uniform mat4 mView;
    uniform mat4 mProj;
    void main() {  
        vec3 theta = vec3(15.0,30.0,20.0);
        vec3 angles = radians(theta);
        vec3  c = cos(angles);
        vec3  s = sin(angles);
        mat4 rx = mat4(1.0, 0.0, 0.0, 0.0,
                   0.0, c.x, s.x, 0.0,
                   0.0,-s.x, c.x, 0.0,
                   0.0, 0.0, 0.0, 1.0);
        mat4 ry = mat4(c.y, 0.0,-s.y, 0.0,
                       0.0, 1.0, 0.0, 0.0,
                       s.y, 0.0, c.y, 0.0,
                       0.0, 0.0, 0.0, 1.0); 
                                
        gl_Position =  mProj * mView * mWorld * rx * aPosition  ;
        gl_PointSize = 10.0;
        vUv = aUv;
    }
`,
        fshader: `
    #ifdef GL_ES
     precision mediump float;
     #endif
    uniform sampler2D uMap0;
    varying vec2 vUv;
    void main() {  
        gl_FragColor = texture2D(uMap0,vUv);
    }
`
    })
        .withState(compileShader)
        .then(linkShader)
        .then(shader => {
            gl.useProgram(shader.program);
            gl.clearColor(0.0,0.0,0.0,1.0);
            gl.clear(gl.COLOR_BUFFER_BIT);
            gl.enable(gl.DEPTH_TEST);
            gl.enable(gl.CULL_FACE);
            gl.frontFace(gl.CCW);
            gl.cullFace(gl.BACK);

            // const buffer = gl.createBuffer();
            // gl.bindBuffer(gl.ARRAY_BUFFER,buffer);
            // var  aPosition = gl.getAttribLocation(shader.program,"aPosition");
            // gl.vertexAttribPointer(aPosition,2,gl.FLOAT,false,0,0);
            // gl.enableVertexAttribArray(aPosition);
            // gl.bufferData(gl.ARRAY_BUFFER,new Float32Array([0.0,0.5,0.0,1.0]),gl.STATIC_DRAW);
            // gl.drawArrays(gl.POINTS,0,1);

            const buffer = gl.createBuffer();
            gl.bindBuffer(gl.ARRAY_BUFFER,buffer);
            var  aPosition = gl.getAttribLocation(shader.program,"aPosition");
            gl.vertexAttribPointer(aPosition,3,gl.FLOAT,false,3 * Float32Array.BYTES_PER_ELEMENT,0);
            gl.enableVertexAttribArray(aPosition);
            gl.bufferData(gl.ARRAY_BUFFER,new Float32Array([
                // front
                -1.0, -1.0,  1.0,
                1.0, -1.0,  1.0,
                1.0,  1.0,  1.0,
                -1.0,  1.0,  1.0,

                // back
                -1.0, -1.0, -1.0,
                -1.0,  1.0, -1.0,
                1.0,  1.0, -1.0,
                1.0, -1.0, -1.0,

                // upside
                -1.0,  1.0, -1.0,
                -1.0,  1.0,  1.0,
                1.0,  1.0,  1.0,
                1.0,  1.0, -1.0,

                // downslide
                -1.0, -1.0, -1.0,
                1.0, -1.0, -1.0,
                1.0, -1.0,  1.0,
                -1.0, -1.0,  1.0,

                // right
                1.0, -1.0, -1.0,
                1.0,  1.0, -1.0,
                1.0,  1.0,  1.0,
                1.0, -1.0,  1.0,

                // left
                -1.0, -1.0, -1.0,
                -1.0, -1.0,  1.0,
                -1.0,  1.0,  1.0,
                -1.0,  1.0, -1.0
            ]),gl.STATIC_DRAW);
           // gl.bindBuffer(gl.ARRAY_BUFFER, null);
            //gl.drawArrays(gl.TRIANGLE,0,4);
            //gl.drawArrays(gl.TRIANGLES,0,36);

            var cubeVerticesIndexBuffer = gl.createBuffer();
            gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, cubeVerticesIndexBuffer);
            gl.bufferData(gl.ELEMENT_ARRAY_BUFFER,
                new Uint16Array( [
                    0,  1,  2,     0,  2,  3,
                    4,  5,  6,     4,  6,  7,
                    8,  9, 10,     8, 10, 11,
                    12, 13, 14,    12, 14, 15,
                    16, 17, 18,    16, 18, 19,
                    20, 21, 22,    20, 22, 23
                ]), gl.STATIC_DRAW);


            var matWorldUniformLocation = gl.getUniformLocation(shader.program, 'mWorld');
            var matViewUniformLocation = gl.getUniformLocation(shader.program, 'mView');
            var matProjUniformLocation = gl.getUniformLocation(shader.program, 'mProj');

            var worldMatrix = new Float32Array(16);
            var viewMatrix = new Float32Array(16);
            var projMatrix = new Float32Array(16);
            mat4.identity(worldMatrix);
            mat4.lookAt(viewMatrix, [0, 0, -8], [0, 0, 0], [0, 1, 0]);
            mat4.perspective(projMatrix, glMatrix.toRadian(45), canvas.clientWidth / canvas.clientHeight, 0.1, 1000.0);

            gl.uniformMatrix4fv(matWorldUniformLocation, gl.FALSE, worldMatrix);
            gl.uniformMatrix4fv(matViewUniformLocation, gl.FALSE, viewMatrix);
            gl.uniformMatrix4fv(matProjUniformLocation, gl.FALSE, projMatrix);




            //{ semantic: pc.SEMANTIC_TEXCOORD0, components: 2, type: pc.TYPE_FLOAT32 }

            // new Float32BufferAttribute( uvs, 2 )
            const tbuffer = gl.createBuffer();
            gl.bindBuffer(gl.ARRAY_BUFFER,tbuffer);
            gl.bufferData(gl.ARRAY_BUFFER,new Float32Array([
                0.0,  0.0,
                1.0,  0.0,
                0.0,  1.0,
                0.0,  1.0,
                1.0,  0.0,
                1.0,  1.0
            ]),gl.STATIC_DRAW);
            var  aUv = gl.getAttribLocation(shader.program,"aUv");
            gl.enableVertexAttribArray(aUv);
            gl.vertexAttribPointer(aUv,2,gl.FLOAT,false,0,0);
            gl.bindBuffer(gl.ARRAY_BUFFER, null);
            //
            //
            //
            //
            //
            //
            var texture1 = gl.createTexture();
            gl.bindTexture(gl.TEXTURE_2D,texture1);
            gl.pixelStorei(gl.UNPACK_FLIP_Y_WEBGL,true);
            var img = _downsampleImage(image,maxTextureSize);

            gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA,gl.RGBA,gl.UNSIGNED_BYTE, img);
            gl.generateMipmap(gl.TEXTURE_2D);
            gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_MIN_FILTER,gl.NEAREST_MIPMAP_LINEAR);
            gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_MAG_FILTER,gl.NEAREST);
            //图片的分辨率不属于2的幂数 需要设置
            gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
            gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);




            var textureUnitIndex = 0;
            gl.activeTexture(gl.TEXTURE0 + textureUnitIndex);
            gl.bindTexture(gl.TEXTURE_2D,texture1);
            gl.uniform1i(gl.getUniformLocation(shader.program,"uMap0"),textureUnitIndex);


            gl.drawElements(this.gl.TRIANGLES, 36, this.gl.UNSIGNED_SHORT, 0);

            return ShaderState.of(shader);
        })
        .runState({});

});


var maxTextureSize = gl.getParameter( gl.MAX_TEXTURE_SIZE );
const _downsampleImage =  (image, size) => {
    var srcW = image.width;
    var srcH = image.height;

    if ((srcW > size) || (srcH > size)) {
        var scale = size / Math.max(srcW, srcH);
        var dstW = Math.floor(srcW * scale);
        var dstH = Math.floor(srcH * scale);

        console.warn('Image dimensions larger than max supported texture size of ' + size + '. ' +
            'Resizing from ' + srcW + ', ' + srcH + ' to ' + dstW + ', ' + dstH + '.');

        var canvas = document.createElement('canvas');
        canvas.width = dstW;
        canvas.height = dstH;

        var context = canvas.getContext('2d');
        context.drawImage(image, 0, 0, srcW, srcH, 0, 0, dstW, dstH);

        return canvas;
    }

    return image;
};


function destroy() {
    var idx = device.shaders.indexOf(_shader);
    if (idx !== -1) {
        device.shaders.splice(idx, 1);
    }

    if (_shader.program) {
        gl.deleteProgram(_shader.program);
        _shader.program = null;
        device.removeShaderFromCache(_shader);
    }
}


