#include <emscripten.h>
#include <GLES3/gl3.h>
#include <GLES3/gl32.h> // GL_GEOMETRY_SHADER
#include <GLFW/glfw3.h>

#include <math.h>
#include <stdio.h>
#include <stdlib.h>

const int MAX_SKELETON = 32;
const int MAX_FISH = 64;

const int SCREEN_WIDTH = 176;
const int SCREEN_HEIGHT = 432;

const int VSCALE = 1;
const int VSCREEN_WIDTH = SCREEN_WIDTH * VSCALE;
const int VSCREEN_HEIGHT = SCREEN_HEIGHT * VSCALE;

const float vscreen_quad[] = {
    -1.0f, -1.0f, 0.0f,
    +1.0f, -1.0f, 0.0f,
    -1.0f, +1.0f, 0.0f,
    -1.0f, +1.0f, 0.0f,
    +1.0f, +1.0f, 0.0f,
    +1.0f, -1.0f, 0.0f
};

typedef struct vec2 {
    float x;
    float y;
} vec2;

typedef struct skeleton_t {
    vec2 points[MAX_SKELETON];
    int  length;
} skeleton_t;

typedef struct fish_t {
    vec2       position;
    skeleton_t bones;
} fish_t;

static fish_t fishes[MAX_FISH];
static int    num_fishes;

static struct {
    float        screen[3];
    unsigned int ticks;
} uniforms;

const char *tank_vertex_shader   = @@vert:tank@@;
const char *tank_fragment_shader = @@frag:tank@@;

const char *fish_vertex_shader   = @@vert:fish@@;
const char *fish_fragment_shader = @@frag:fish@@;

const char *dither_vertex_shader   = @@vert:dither@@;
const char *dither_fragment_shader = @@frag:dither@@;

static GLuint framebuffer;
static GLuint texture_vscreen;

static GLFWwindow *window;
static int enable_uniforms = 0;
static GLuint ubo_uniforms;
static GLuint shader_tank, vbo_tank, vao_tank;
//vbo_fish layout:
//  2 floats (position)
//  1 float  (direction)
static GLuint shader_fish, vbo_fish, vao_fish;
static GLuint shader_dither, vbo_quad, vao_quad;

static void init_glfw() {
    if (! glfwInit()) {
        fprintf(stderr, "ERROR: could not start GLFW3.\n");
        exit(1);
    }
}

static GLFWwindow* init_window() {
    window = glfwCreateWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "Hello Triangle", NULL, NULL);
    if (! window) {
        fprintf(stderr, "ERROR: Could not open window with GLFW3.\n");
        glfwTerminate();
        return NULL;
    }
    glfwMakeContextCurrent(window);
    glfwWindowHint(GLFW_CLIENT_API, GLFW_OPENGL_ES_API);
    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3);
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 0);
    return window;
}

static void init_vscreen_quad() {
    vbo_quad = 0;
    glGenBuffers(1, &vbo_quad);
    glBindBuffer(GL_ARRAY_BUFFER, vbo_quad);
    glBufferData(GL_ARRAY_BUFFER, (3*6) * sizeof(float), vscreen_quad, GL_STATIC_DRAW);

    vao_quad = 0;
    glGenVertexArrays(1, &vao_quad);
    glBindVertexArray(vao_quad);
    glEnableVertexAttribArray(0);
    glBindBuffer(GL_ARRAY_BUFFER, vbo_quad);
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 0, NULL);
}

static void create_tank_shader() {
    GLuint vs = glCreateShader(GL_VERTEX_SHADER);
    glShaderSource(vs, 1, &tank_vertex_shader, NULL);
    glCompileShader(vs);
    GLuint fs = glCreateShader(GL_FRAGMENT_SHADER);
    glShaderSource(fs, 1, &tank_fragment_shader, NULL);
    glCompileShader(fs);

    shader_tank = glCreateProgram();
    glAttachShader(shader_tank, fs);
    glAttachShader(shader_tank, vs);
    glLinkProgram(shader_tank);
    glValidateProgram(shader_tank);
}

static void create_fish_shader() {
    vbo_fish = 0;
    glGenBuffers(1, &vbo_fish);
    glBindBuffer(GL_ARRAY_BUFFER, vbo_fish);

    vao_fish = 0;
    glGenVertexArrays(1, &vao_fish);
    glBindVertexArray(vao_fish);
    glEnableVertexAttribArray(0);
    glBindBuffer(GL_ARRAY_BUFFER, vbo_fish);
    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 0, NULL);

    GLuint vs = glCreateShader(GL_VERTEX_SHADER);
    glShaderSource(vs, 1, &fish_vertex_shader, NULL);
    glCompileShader(vs);
    GLuint fs = glCreateShader(GL_FRAGMENT_SHADER);
    glShaderSource(fs, 1, &fish_fragment_shader, NULL);
    glCompileShader(fs);

    shader_fish = glCreateProgram();
    glAttachShader(shader_fish, fs);
    glAttachShader(shader_fish, vs);
    glLinkProgram(shader_fish);
    glValidateProgram(shader_fish);
}

static void create_dither_shader() {
    GLuint vs = glCreateShader(GL_VERTEX_SHADER);
    glShaderSource(vs, 1, &dither_vertex_shader, NULL);
    glCompileShader(vs);
    GLuint fs = glCreateShader(GL_FRAGMENT_SHADER);
    glShaderSource(fs, 1, &dither_fragment_shader, NULL);
    glCompileShader(fs);

    shader_dither = glCreateProgram();
    glAttachShader(shader_dither, fs);
    glAttachShader(shader_dither, vs);
    glLinkProgram(shader_dither);
    glValidateProgram(shader_dither);
}

static void init_vscreen() {
    glGenFramebuffers(1, &framebuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, framebuffer);

    glGenTextures(1, &texture_vscreen);
    glBindTexture(GL_TEXTURE_2D, texture_vscreen);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB, VSCREEN_WIDTH, VSCREEN_HEIGHT, 0, GL_RGB, GL_UNSIGNED_BYTE, 0);

    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);

    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, texture_vscreen, 0);

    if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE) {
        fprintf(stderr, "framebuffer failure");
        glfwTerminate();
    }
}

static void init_uniforms(GLint program, GLint *ubo, GLuint binding) {
    glUseProgram(program);

    GLint index = glGetUniformBlockIndex(program, "GlobalParams_std140");

    if (index == GL_INVALID_INDEX) {
        printf("UBO not found, probably optimized away\n");
        glUseProgram(0);
        return;
    }
    enable_uniforms = 1;

    glUniformBlockBinding(program, index, binding);   

    GLint size;
    glGetActiveUniformBlockiv(program, index, GL_UNIFORM_BLOCK_DATA_SIZE, &size);

    glGenBuffers(1, ubo);
    glBindBuffer(GL_UNIFORM_BUFFER, *ubo);
    glBufferData(GL_UNIFORM_BUFFER, size, NULL, GL_DYNAMIC_DRAW);

    glBindBufferBase(GL_UNIFORM_BUFFER, binding, *ubo);

    glUseProgram(0);
}

static void init_shaders() {
    uniforms.screen[0] = VSCREEN_WIDTH;
    uniforms.screen[1] = VSCREEN_HEIGHT;
    uniforms.screen[2] = 1.0;
    uniforms.ticks = 0;

    fish_t f;
    f.position.x = 0.0;
    f.position.y = 0.0;
    f.bones.points[0].x = -0.4;
    f.bones.points[0].y = 0.0;
    f.bones.points[1].x = 0.4;
    f.bones.points[1].y = 0.0;
    f.bones.length = 2;
    fishes[num_fishes++] = f;

    init_vscreen_quad();
    init_vscreen();
    create_tank_shader();
    create_fish_shader();
    create_dither_shader();
    init_uniforms(shader_tank, &ubo_uniforms, 1);
}

static void draw_tank() {
    //TODO
    glUseProgram(shader_tank);
    glActiveTexture(GL_TEXTURE1);
    //glBindTexture(GL_TEXTURE_2D, texture_vscreen);
    //glViewport(0, 0, VSCREEN_WIDTH, VSCREEN_HEIGHT);
    glBindFramebuffer(GL_FRAMEBUFFER, framebuffer);
    GLenum drawBuffers[1] = { GL_COLOR_ATTACHMENT0 };
    glDrawBuffers(1, drawBuffers);
    //upload uniforms
    if (enable_uniforms) {
        glBindBuffer(GL_UNIFORM_BUFFER, ubo_uniforms);
        glBufferSubData(GL_UNIFORM_BUFFER, 0, sizeof(uniforms), &uniforms);
    }
    //attach tank vertices
    glBindBuffer(GL_ARRAY_BUFFER, vbo_quad);
    glBindVertexArray(vao_quad);
    glEnableVertexAttribArray(0);
    //draw
    glDrawArrays(GL_TRIANGLES, 0, 6);
    //cleanup
    glBindVertexArray(0);
    glBindBuffer(GL_ARRAY_BUFFER, 0);
    glBindBuffer(GL_UNIFORM_BUFFER, 0);
    glBindVertexArray(0);
    glUseProgram(0);
}

static void draw_fish(fish_t fish) {
    glUseProgram(shader_fish);
    //upload fish
    float vertices[512]; 
    int   i_vertices = 0;
    glBindBuffer(GL_ARRAY_BUFFER, vbo_fish);
    //take first and last bone point
    vec2 p1 = fish.bones.points[0];
    vec2 p2 = fish.bones.points[fish.bones.length-1];
    float r1 = 0.05;
    float r2 = fabs((p2.x+p2.y)/2.0 - (p1.x+p2.y)/2.0);
    int   N  = 60;
    float ymid = (p2.y + p1.y)/2.0;
    float xmid = (p2.x + p1.x)/2.0;
    vertices[i_vertices++] = xmid;
    vertices[i_vertices++] = ymid;
    for (int i = 0; i < N; i++) {
        float rad = (i*2*M_PI)/(float)(N-2);
        float y   = sinf(rad)*r1;
        float x   = cosf(rad)*r2;
        vertices[i_vertices++] = xmid + x;
        vertices[i_vertices++] = ymid + y;
    }
    vertices[i_vertices++] = xmid + cosf(0)*r2;
    vertices[i_vertices++] = ymid + sinf(0)*r1;
    glBufferData(GL_ARRAY_BUFFER, (N+1) * 2 * sizeof(float), vertices, GL_DYNAMIC_DRAW);
    //bind framebuffer
    glActiveTexture(GL_TEXTURE1);
    //glBindTexture(GL_TEXTURE_2D, texture_vscreen);
    //glViewport(0, 0, VSCREEN_WIDTH, VSCREEN_HEIGHT);
    glBindFramebuffer(GL_FRAMEBUFFER, framebuffer);
    GLenum drawBuffers[1] = { GL_COLOR_ATTACHMENT0 };
    glDrawBuffers(1, drawBuffers);
    //upload uniforms
    if (enable_uniforms) {
        //glBindBuffer(GL_UNIFORM_BUFFER, ubo_uniforms);
        //glBufferSubData(GL_UNIFORM_BUFFER, 0, sizeof(uniforms), &uniforms);
    }
    //draw
    //glDrawArrays(GL_TRIANGLE_FAN, 0, 1+N);
    glBindVertexArray(vao_fish);
    glBindBuffer(GL_ARRAY_BUFFER, vbo_fish);
    glEnableVertexAttribArray(0);
    glDrawArrays(GL_TRIANGLE_FAN, 0, N+1);
    //cleanup
    glBindBuffer(GL_UNIFORM_BUFFER, 0);
    glBindVertexArray(0);
    glUseProgram(0);
}

static void draw_vscreen() {
    glUseProgram(shader_dither);
    //attach tank vertices
    glBindVertexArray(vao_quad);
    //draw
    glDrawArrays(GL_TRIANGLES, 0, 6);
    glBindTexture(GL_TEXTURE_2D, 0);
    glUseProgram(0);
}

static void render() {
    uniforms.ticks++;
    glfwPollEvents();
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    //draw to vscreen
    draw_tank();
    for (int i = 0; i < num_fishes; i++) {
        draw_fish(fishes[i]);
    }
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    //glViewport(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT);
    draw_vscreen();
    glfwSwapBuffers(window);
}

int main(void) {
    init_glfw();
    init_window();
    init_shaders();

    emscripten_set_main_loop(render, 0, 1);

    glfwTerminate();
    return 0;
}
