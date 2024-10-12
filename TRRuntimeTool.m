
#import "TRRuntimeTool.h"
#include <Foundation/Foundation.h>
#import <SpringBoardServices/SpringBoardServices.h>

#include <dlfcn.h>
#include <mach-o/dyld.h>
#include <mach-o/dyld_images.h>
#include <mach/mach.h>
#include <sys/sysctl.h>

kern_return_t mach_vm_read_overwrite(vm_map_t, mach_vm_address_t, mach_vm_size_t, mach_vm_address_t,
                                     mach_vm_size_t *);
kern_return_t mach_vm_region(vm_map_read_t target_task, mach_vm_address_t *address,
                             mach_vm_size_t *size, vm_region_flavor_t flavor, vm_region_info_t info,
                             mach_msg_type_number_t *infoCnt, mach_port_t *object_name);

BOOL readProcessMemory(task_t targetTask, mach_vm_address_t address, mach_vm_size_t size,
                       unsigned char *buffer) {
    mach_vm_size_t outSize = 0;

    kern_return_t kr =
        mach_vm_read_overwrite(targetTask, address, size, (mach_vm_address_t)buffer, &outSize);
    if (kr != KERN_SUCCESS || outSize != size) {
        return NO;
    }

    return YES;
}

static kern_return_t readmem(mach_vm_offset_t *buffer, mach_vm_address_t address,
                             mach_vm_size_t size, task_t targetTask,
                             vm_region_basic_info_data_64_t *info) {
    kern_return_t kr;
    mach_msg_type_number_t info_cnt = sizeof(vm_region_basic_info_data_64_t);
    mach_port_t object_name;
    mach_vm_size_t size_info;
    mach_vm_address_t address_info = address;
    kr = mach_vm_region(targetTask, &address_info, &size_info, VM_REGION_BASIC_INFO_64,
                        (vm_region_info_t)info, &info_cnt, &object_name);
    if (kr) {
        fprintf(stderr, "[ERROR] mach_vm_region failed with error %d\n", (int)kr);
        return KERN_FAILURE;
    }

    /* read memory - vm_read_overwrite because we supply the buffer */
    mach_vm_size_t nread;
    kr = mach_vm_read_overwrite(targetTask, address, size, (mach_vm_address_t)buffer, &nread);
    if (kr) {
        fprintf(stderr, "[ERROR] vm_read failed! %d\n", kr);
        return KERN_FAILURE;
    } else if (nread != size) {
        fprintf(stderr, "[ERROR] vm_read failed! requested size: 0x%llx read: 0x%llx\n", size,
                nread);
        return KERN_FAILURE;
    }
    return KERN_SUCCESS;
}

struct segmentRange {
    unsigned long long start;
    unsigned long long end;
};

struct segmentRange getImageTextSegmentAddr(mach_vm_address_t address, task_t targetTask,
                                            NSMutableString *msg) {
    struct segmentRange textSegRange = {0, 0};
    struct mach_header_64 header = {0};
    vm_region_basic_info_data_64_t region_info = {0};
    if (readmem((mach_vm_offset_t *)&header, address, sizeof(struct mach_header_64), targetTask,
                &region_info)) {
        [msg appendString:@"[-] can't read header!"];
        return textSegRange;
    }

    if (header.magic != MH_MAGIC_64) {
        [msg appendString:@"[-] only arm64 files can be analyzed."];
        return textSegRange;
    }

    struct load_command *lc = (struct load_command *)malloc(header.sizeofcmds);
    if (readmem((mach_vm_offset_t *)lc, address + sizeof(struct mach_header_64), header.sizeofcmds,
                targetTask, &region_info)) {
        [msg appendString:@"[-] can't read load_command!"];
        free(lc);
        return textSegRange;
    }

    int ncmds = header.ncmds;
    struct load_command *lcp = (struct load_command *)((mach_vm_address_t)lc);

    while (ncmds--) {
        if (lcp->cmd == LC_SEGMENT_64) {
            struct segment_command_64 *sc = (struct segment_command_64 *)lcp;

            if (!strncmp(sc->segname, "__TEXT", 16)) {
                uint32_t aslr_slide = address - sc->vmaddr;
                struct section_64 *sect = (struct section_64 *)((mach_vm_address_t)sc +
                                                                sizeof(struct segment_command_64));
                if (!strncmp(sect->sectname, "__text", 16)) {
                    textSegRange.start = sect->addr + aslr_slide;
                    textSegRange.end = textSegRange.start + sect->size;
                    break;
                }
            }
        }

        lcp = (struct load_command *)((mach_vm_address_t)lcp + lcp->cmdsize);
    }

    free(lc);
    return textSegRange;
}

mach_vm_address_t lookup_ptrace_svc(task_t targetTask, mach_vm_address_t target_addr, uint64_t size,
                                    NSMutableString *msg) {
    uint64_t read_size = 0x1000;
    uint8_t buffer[read_size];
    mach_vm_size_t bytesRead;

    for (uint64_t offset = 0; offset < size; offset += bytesRead) {
        mach_vm_address_t address = target_addr + offset;
        kern_return_t kr = mach_vm_read_overwrite(targetTask, address, read_size,
                                                  (mach_vm_address_t)buffer, &bytesRead);
        if (kr != KERN_SUCCESS || bytesRead == 0) {
            break;
        }

        uint32_t instr;
        for (mach_vm_size_t i = 0; i < bytesRead; i += 4) {
            if (i + 4 > bytesRead) {
                break;
            }

            instr = *(uint32_t *)(buffer + i);
            /*
                mov       x16, #0x1a    -> 0xd2800350
                svc       #0x80         -> 0xd4001001
            */
            if (instr == 0xd2800350) {
                if (i + 8 <= bytesRead) {
                    instr = *(uint32_t *)(buffer + i + 4);
                    if (instr == 0xd4001001) {
                        return address + i;
                    }
                }
            }
        }
    }

    return -1;
}

@implementation AppRuntimeTool

+ (NSArray *)listProcess {
    // 用于存储进程信息的指针
    struct kinfo_proc *processes = NULL;
    int count, i = 0;

    int mib[4] = {CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0};
    size_t size;
    if (sysctl(mib, 4, NULL, &size, NULL, 0) != 0) {
        return NULL;
    }

    while (YES) {
        size_t previous_size;

        processes = realloc(processes, size);
        previous_size = size;
        if (sysctl(mib, 4, processes, &size, NULL, 0) == 0) break;

        if (!(errno == ENOMEM)) return NULL;

        size = previous_size * 11 / 10;
    }

    NSMutableArray *rets = [NSMutableArray array];

    count = size / sizeof(struct kinfo_proc);
    for (i = 0; i != count; i++) {
        struct kinfo_proc *process = &processes[i];

        NSString *identifier =
            (__bridge NSString *)SBSCopyDisplayIdentifierForProcessID(process->kp_proc.p_pid);
        if (identifier != nil) {
            if ([identifier isEqualToString:@"com.zznq.trollr2ool"]) continue;

            NSString *name =
                (__bridge NSString *)SBSCopyLocalizedApplicationNameForDisplayIdentifier(
                    (__bridge CFStringRef)identifier);

            [rets addObject:@{
                @"pid" : @(process->kp_proc.p_pid),
                @"bundleID" : identifier,
                @"name" : name,
            }];
        }
    }

    return rets;
}

+ (NSString *)lookupPtraceSvc:(pid_t)pid {
    NSMutableString *msg = [[NSMutableString alloc] init];

    task_t targetTask;
    kern_return_t kr = task_for_pid(mach_task_self(), pid, &targetTask);
    if (kr != KERN_SUCCESS) {
        [msg appendString:[NSString stringWithFormat:@"[-] failed to get task for pid %d\n", pid]];
        return msg;
    }

    struct task_dyld_info dyld_info;
    mach_msg_type_number_t count = TASK_DYLD_INFO_COUNT;
    kr = task_info(targetTask, TASK_DYLD_INFO, (task_info_t)&dyld_info, &count);
    if (kr != KERN_SUCCESS) {
        [msg appendString:@"[-] failed to read dyld_info\n"];
        return msg;
    }

    mach_vm_size_t size = sizeof(struct dyld_all_image_infos);
    uint8_t images_addr[size];
    if (!readProcessMemory(targetTask, dyld_info.all_image_info_addr, size, images_addr)) {
        [msg appendString:@"[-] failed to read dyld_all_image_infos\n"];
        return msg;
    }
    struct dyld_all_image_infos *infos = (struct dyld_all_image_infos *)images_addr;
    if (infos->infoArrayCount == 0) {
        [msg appendString:@"[-] no images found\n"];
        return msg;
    }

    size = sizeof(struct dyld_image_info) * infos->infoArrayCount;
    uint8_t info_addr[size];
    if (!readProcessMemory(targetTask, (mach_vm_address_t)infos->infoArray, size, info_addr)) {
        [msg appendString:@"[-] failed to read dyld_image_info\n"];
        return msg;
    }
    struct dyld_image_info *info = (struct dyld_image_info *)info_addr;

    // main executable image
    mach_vm_address_t imageAddress = (mach_vm_address_t)info[0].imageLoadAddress;
    [msg appendString:[NSString
                          stringWithFormat:@"[+] found main image addres: 0x%llx\n", imageAddress]];
    struct segmentRange textSegRange = getImageTextSegmentAddr(imageAddress, targetTask, msg);
    if (textSegRange.start != 0 || textSegRange.end != 0) {
        [msg appendString:
                 [NSString stringWithFormat:@"[+] found text segment:\nstart(0x%llx)-end(0x%llx)\n",
                                            textSegRange.start, textSegRange.end]];

        mach_vm_address_t svc = lookup_ptrace_svc(targetTask, textSegRange.start,
                                                  textSegRange.start - textSegRange.end, msg);
        if (svc != -1) {
            [msg appendString:[NSString stringWithFormat:@"[+] found ptrace svc:\n"
                                                         @"\t0x%llx - (mov x16, #0x1a)\n"
                                                         @"\t0x%llx - (svc #0x80)",
                                                         svc, svc + 4]];
        }
    }

    return msg;
}

@end
