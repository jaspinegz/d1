#include <emscripten.h>
#include <GLES3/gl3.h>
#include <GLFW/glfw3.h>

#include <stdio.h>

const int V_SCREEN_WIDTH = 88;
const int V_SCREEN_HEIGHT = 216;
const int V_SCALE = 2;

const int SCREEN_WIDTH = V_SCREEN_WIDTH * V_SCALE;
const int SCREEN_HEIGHT = V_SCREEN_HEIGHT * V_SCALE;

static GLFWwindow *window;
static GLuint shader_program, vao;

static void loop(void) {
    glfwPollEvents();

    glClear( GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT );

    glUseProgram( shader_program );
    glBindVertexArray( vao );

    glDrawArrays( GL_TRIANGLES, 0, 3 );

    glfwSwapBuffers( window );
}

int main( void ) {
  if ( !glfwInit() ) {
    fprintf( stderr, "ERROR: could not start GLFW3.\n" );
    return 1;
  }

  glfwWindowHint( GLFW_CLIENT_API, GLFW_OPENGL_ES_API );
  glfwWindowHint( GLFW_CONTEXT_VERSION_MAJOR, 3 );
  glfwWindowHint( GLFW_CONTEXT_VERSION_MINOR, 0 );

  window = glfwCreateWindow( SCREEN_WIDTH, SCREEN_HEIGHT, "Hello Triangle", NULL, NULL );
  if ( !window ) {
    fprintf( stderr, "ERROR: Could not open window with GLFW3.\n" );
    glfwTerminate();
    return 1;
  }
  glfwMakeContextCurrent( window );

  float points[] = {
      0.0f,  0.5f,  0.0f, // x,y,z of first point.
      0.5f, -0.5f,  0.0f, // x,y,z of second point.
      -0.5f, -0.5f,  0.0f  // x,y,z of third point.
  };

  GLuint vbo = 0;
  glGenBuffers( 1, &vbo );
  glBindBuffer( GL_ARRAY_BUFFER, vbo );
  glBufferData( GL_ARRAY_BUFFER, 9 * sizeof( float ), points, GL_STATIC_DRAW );

  vao = 0;
  glGenVertexArrays( 1, &vao );
  glBindVertexArray( vao );
  glEnableVertexAttribArray( 0 );
  glBindBuffer( GL_ARRAY_BUFFER, vbo );
  glVertexAttribPointer( 0, 3, GL_FLOAT, GL_FALSE, 0, NULL );

  const char* vertex_shader =
      "#version 300 es\n"
      "layout(location = 0) in vec3 vp;"
      "void main() {"
      "  gl_Position = vec4( vp, 1.0 );"
      "}";

  const char* fragment_shader =
      "#version 300 es\n"
      "precision mediump float;"
      "out vec4 frag_colour;"
      "void main() {"
      "  frag_colour = vec4( 0.5, 0.0, 0.5, 1.0 );"
      "}";

  GLuint vs = glCreateShader( GL_VERTEX_SHADER );
  glShaderSource( vs, 1, &vertex_shader, NULL );
  glCompileShader( vs );
  GLuint fs = glCreateShader( GL_FRAGMENT_SHADER );
  glShaderSource( fs, 1, &fragment_shader, NULL );
  glCompileShader( fs );

  shader_program = glCreateProgram();
  glAttachShader( shader_program, fs );
  glAttachShader( shader_program, vs );
  glLinkProgram( shader_program );

  emscripten_set_main_loop(loop, 0, 1);
  
  glfwTerminate();
  return 0;
}
