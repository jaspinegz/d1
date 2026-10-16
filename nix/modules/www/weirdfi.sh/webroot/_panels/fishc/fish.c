#include <emscripten.h>
#include <GLES3/gl3.h>
#include <GLFW/glfw3.h>

#include <stdio.h>
#include <stdlib.h>

const int V_SCREEN_WIDTH = 88;
const int V_SCREEN_HEIGHT = 216;
const int V_SCALE = 2;

const int SCREEN_WIDTH = V_SCREEN_WIDTH * V_SCALE;
const int SCREEN_HEIGHT = V_SCREEN_HEIGHT * V_SCALE;

static struct {
    float screen[3];
    unsigned int ticks;
} uniforms;

const char *tank_vertex_shader   = @@vert:tank@@;
const char *tank_fragment_shader = @@frag:tank@@;

static GLFWwindow *window;
static int enable_uniforms = 0;
static GLuint ubo_uniforms;
static GLuint shader_tank, vbo_tank, vao_tank;

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

static void create_tank_shader() {
    const float tank_vertices[] = {
        -1.0f, -1.0f, 0.0f,
        +1.0f, -1.0f, 0.0f,
        -1.0f, +1.0f, 0.0f,
        -1.0f, +1.0f, 0.0f,
        +1.0f, +1.0f, 0.0f,
        +1.0f, -1.0f, 0.0f
    };

    vbo_tank = 0;
    glGenBuffers(1, &vbo_tank);
    glBindBuffer(GL_ARRAY_BUFFER, vbo_tank);
    glBufferData(GL_ARRAY_BUFFER, (3*8) * sizeof(float), tank_vertices, GL_STATIC_DRAW);

    vao_tank = 0;
    glGenVertexArrays(1, &vao_tank);
    glBindVertexArray(vao_tank);
    glEnableVertexAttribArray(0);
    glBindBuffer(GL_ARRAY_BUFFER, vbo_tank);
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 0, NULL);

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

static void draw_tank() {
    //TODO
    glUseProgram(shader_tank);
    //upload uniforms
    if (enable_uniforms) {
        glBindBuffer(GL_UNIFORM_BUFFER, ubo_uniforms);
        glBufferSubData(GL_UNIFORM_BUFFER, 0, sizeof(uniforms), &uniforms);
    }
    //attach tank vertices
    glBindVertexArray(vao_tank);
    //draw
    glDrawArrays(GL_TRIANGLES, 0, 6);
    //cleanup
    glBindBuffer(GL_UNIFORM_BUFFER, 0);
    glBindVertexArray(0);
    glUseProgram(0);
}

static void draw_water() {
}

static void draw_fish() {
}

static void init_uniforms(GLint program) {
    glUseProgram(program);

    const GLuint binding_uniforms = 1; 
    GLint index = glGetUniformBlockIndex(program, "GlobalParams_std140");

    if (index == GL_INVALID_INDEX) {
        printf("UBO not found, probably optimized away\n");
        enable_uniforms = 0;
        glUseProgram(0);
        return;
    }
    enable_uniforms = 1;

    glUniformBlockBinding(program, index, binding_uniforms);   

    GLint size;
    glGetActiveUniformBlockiv(program, index, GL_UNIFORM_BLOCK_DATA_SIZE, &size);

    glGenBuffers(1, &ubo_uniforms);
    glBindBuffer(GL_UNIFORM_BUFFER, ubo_uniforms);
    glBufferData(GL_UNIFORM_BUFFER, size, NULL, GL_DYNAMIC_DRAW);

    glBindBufferBase(GL_UNIFORM_BUFFER, binding_uniforms, ubo_uniforms);

    glUseProgram(0);
}

static void init_shaders() {
    uniforms.screen[0] = SCREEN_WIDTH;
    uniforms.screen[1] = SCREEN_HEIGHT;
    uniforms.screen[2] = 1.0;
    uniforms.ticks = 0;

    create_tank_shader();
    init_uniforms(shader_tank);
}

static void render() {
    uniforms.ticks++;
    glfwPollEvents();
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    draw_tank();
    draw_water();
    draw_fish();
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
