#import <Foundation/Foundation.h>
extern void adapter_get_env(void);
int main(void) {
    @autoreleasepool {
        adapter_get_env();
    }
    return 0;
}
