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

char* cache;

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

void convertToBytesMetric(double bytes_per_sec, char* output) {
    if (bytes_per_sec >= 1048576) {
        sprintf(output, "%0.1fMiB/s", bytes_per_sec / 1048576.);
    } else if (bytes_per_sec >= 1024) {
        sprintf(output, "%0.1fKiB/s", bytes_per_sec / 1024.);
    } else {
        sprintf(output, "%0.1fB/s", bytes_per_sec * 1.);
    }
}

void writeBytesToFile(const char* path, uint64_t num) {
    int fd = open(path, O_CREAT | O_WRONLY, S_IRUSR | S_IWUSR);
    int str_size = sprintf(cache, "%" SCNu64, num);
    write(fd, cache, str_size);
    close(fd);
}

int main(int argc, char* argv[]) {
    if(argc != 2) {
        return 1;
    }

    cache = calloc(BYTE_CACHE_SIZE, sizeof(char));
    
    if (strcmp(argv[1], "rx") == 0) {
        uint64_t rx1;
        uint64_t rx2 = readBytes("/sys/class/net/enp2s0/statistics/rx_bytes");
        rx2 += readBytes("/sys/class/net/wlan0/statistics/rx_bytes");
        
        if (access("./rx", F_OK) != 0) {
            rx1 = rx2;
            writeBytesToFile("./rx", rx1);
        } else {
            rx1 = readBytes("./rx");
        }

        struct stat attrs;
        stat("./rx", &attrs);
        double diff = difftime(time(0), attrs.st_mtime);
        if (diff == 0) {
            diff = 1;
        }

        convertToBytesMetric((rx2 - rx1)/diff, cache);
        
        printf("%s", cache);
        writeBytesToFile("./rx", rx2);
    } else if (strcmp(argv[1], "tx") == 0) {
        uint64_t tx1;
        uint64_t tx2 = readBytes("/sys/class/net/enp2s0/statistics/tx_bytes");
        tx2 += readBytes("/sys/class/net/wlan0/statistics/tx_bytes");
        
        if (access("./rx", F_OK) != 0) {
            tx1 = tx2;
            writeBytesToFile("./tx", tx1);
        } else {
            tx1 = readBytes("./tx");
        }

        
        struct stat attrs;
        stat("./tx", &attrs);
        double diff = difftime(time(0), attrs.st_mtime);
        if (diff == 0) {
            diff = 1;
        }

        convertToBytesMetric((tx2 - tx1)/diff, cache);
        
        printf("%s", cache);
        writeBytesToFile("./tx", tx2);
    }

    return 0;
}