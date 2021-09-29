#include <stdlib.h>
#include <stdio.h>

int main(int argc, char* argv[]) {
    if (argc != 4) {
        return 1;
    }

    unsigned long long old = strtoull(argv[1], NULL, 10);
    if (old == 0) {
        return 1;
    }

    unsigned long long new = strtoull(argv[2], NULL, 10);
    if (new == 0) {
        return 1;
    }

    double mult = strtod(argv[3], NULL);
    if (mult == 0) {
        return 1;
    }

    double value = (new - old) / (mult);
    
    if (value > (1024*1024)) {
        printf("%.1fMiB/s", value / (1024.0*1024.0));
    } else if (value > 1024) {
        printf("%.1fKiB/s", value / 1024.0);
    } else {
        printf("%.1fB/s", value);
    } 
    return 0;
}