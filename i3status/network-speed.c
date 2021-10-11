#include <asm-generic/errno-base.h>
#include <stdlib.h>
#include <stdio.h>
#include <stdint.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <errno.h>
#include <unistd.h>
#include <inttypes.h>
#include <time.h>
#include <string.h>

extern int errno;

#define BYTE_CACHE_SIZE 20

char cache[BYTE_CACHE_SIZE];

uint64_t readBytes(const char* path) {
    int fd = open(path, O_RDONLY);
    
    if (fd == -1) {
        printf("ERROR when reading from %s: %d\n", path, errno);
        perror("Read Bytes Failed.");
    }

    int readChars = read(fd, cache, BYTE_CACHE_SIZE);

    char* endptr;
    uint64_t bytes = strtoull(cache, &endptr, 10);
    if (errno == EINVAL || errno == ERANGE) {
        perror("FAILED to convert bytes from string to uint64");
        exit(1);
    }

    return bytes;
}

void writeBytes(const char* path, uint64_t num) {
    int fd = open(path, O_CREAT | O_WRONLY, S_IRUSR | S_IWUSR);
    int str_size = sprintf(cache, "%" SCNu64, num);
    write(fd, cache, str_size);
    close(fd);
}

void printBytesPerSecond(double bytes_per_sec) {
    if (bytes_per_sec >= 1048576) {
        printf("%0.1fMiB/s", bytes_per_sec / 1048576.);
    } else if (bytes_per_sec >= 1024) {
        printf("%0.1fKiB/s", bytes_per_sec / 1024.);
    } else {
        printf("%0.1fB/s", bytes_per_sec * 1.);
    }
}

void printBitsPerSecond(double bytes_per_sec) {
    bytes_per_sec *= 8.;
    if (bytes_per_sec >= 1000000) {
        printf("%0.1fMbps", bytes_per_sec / 1000000.);
    } else if (bytes_per_sec >= 1000) {
        printf("%0.1fKbps", bytes_per_sec / 1000.);
    } else {
        printf("%0.0fbps", bytes_per_sec * 1.);
    }
}

int main(int argc, char* argv[]) {
    if(!(argc == 3 || argc == 2)) {
        return 1;
    }
    if ((strcmp(argv[1], "rx") != 0) && (strcmp(argv[1], "tx") != 0)) {
        return 1;
    }

    char enp2s0_statistics[42];
    char wlan0_statistics[42];
    char cache_file[5];
    sprintf(enp2s0_statistics, "/sys/class/net/enp2s0/statistics/%s_bytes", argv[1]);
    sprintf(wlan0_statistics, "/sys/class/net/wlan0/statistics/%s_bytes", argv[1]);
    sprintf(cache_file, "./%s", argv[1]);
    
    uint64_t last_bytes;
    uint64_t bytes = readBytes(enp2s0_statistics);
    bytes += readBytes(wlan0_statistics);

    if (access(cache_file, F_OK) != 0) {
        last_bytes = bytes;
        writeBytes(cache_file, bytes);
    } else {
        last_bytes = readBytes(cache_file);
    }

    struct stat attrs;
    stat(cache_file, &attrs);
    double diff = difftime(time(0), attrs.st_mtime);
    if (diff == 0) {
        diff = 1;
    }
    
    if (argc == 3 && strcmp(argv[2], "1") == 0) {
        printBytesPerSecond((bytes - last_bytes)/diff);
    } else {
        printBitsPerSecond((bytes - last_bytes)/diff);
    }
    
    writeBytes(cache_file, bytes);

    return 0;
}