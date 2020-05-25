This is an attempt to reproduce what might happen if an EFI firmware writes to a single device of an md raid1 array.

Here's some output from last time I ran this:

```
[setup] cleaning up from last run...done
[setup] creating a fake raid1 EFI system partition...done
[setup] copying some centos efi files into the fake esp...done
[setup] umounting and stopping the fake esp for corruption tests...done

[reboot] this step simulates an EFI boot process that writes to a single disk:
[reboot] mounting loop0 directly and modifying the filesystem...done
[reboot] wrote testlog with md5 c5d9d33e4a4b23165632e2a14bc30ede
[reboot] umounting loop0...done
[reboot] reassemble the raid and run an md raid check...done
[reboot] mismatch_cnt: 768

[yum] simulate that we yum upgrade, writes a new grub.cfg...done

[list] read loop0 directly...done
[list] read loop1 directly...done

[repair] assemble and repair the raid...done

[recheck] check everything again...done
[recheck] mismatch_cnt: 0
all 22 tests passed in 7.831s.
```
