private extern (C) int _d_run_main(int argc, char **argv, void* main);

/***********************************
 * The D main() function supplied by the user's program
 */
int main();

extern (C) int main(int argc, char **argv)
{
    return _d_run_main(argc, argv, &main);
}
