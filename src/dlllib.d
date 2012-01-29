module dlllib;

alias int function(char[][] args) mainFunc;

extern (C) int _d_dll_main(int argc, char** argv, mainFunc main);

/***********************************
* The D main() function supplied by the user's program
*/
int main(char[][] args);

/***********************************
* Substitutes for the C main() function.
* It's purpose is to wrap the call to the D main()
* function and catch any unhandled exceptions.
*/

extern (C) int main(int argc, char** argv)
{
  return _d_dll_main(argc,argv,&main);
}