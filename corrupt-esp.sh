#!/bin/bash

. assert.sh

DIR=$(pwd)

# cleanup from last run
echo -n [setup] cleaning up from last run...
umount /mnt/efi &> /dev/null
mdadm --stop /dev/md1 &> /dev/null
losetup -d /dev/loop0 &> /dev/null
losetup -d /dev/loop1 &> /dev/null
echo done

# create the raid1 "ESP"
echo -n [setup] creating a fake raid1 EFI system partition...
dd if=/dev/zero of=esp-a bs=1M count=128 2> /dev/null
dd if=/dev/zero of=esp-b bs=1M count=128 2> /dev/null
losetup /dev/loop0 esp-a
losetup /dev/loop1 esp-b
assert "mdadm --create /dev/md1 --metadata=1.0 --level=1 --raid-devices=2 /dev/loop[0-1] 2>&1" "mdadm: array /dev/md1 started."
assert_raises "mkfs.vfat /dev/md1"
echo done

# mount and fill with centos 7 efi files
echo -n [setup] copying some centos efi files into the fake esp...
mkdir -p /mnt/efi
mount /dev/md1 /mnt/efi
cd /mnt/efi
assert_raises "tar xf $DIR/EFI.tgz"
echo done

# umount and stop it for corruption tests
echo -n [setup] umounting and stopping the fake esp for corruption tests...
cd - > /dev/null
umount /mnt/efi
assert "mdadm --stop /dev/md1 2>&1" "mdadm: stopped /dev/md1"
echo done

echo

# corruption test 1: mount first dev directly and write like uefi might
echo [reboot] this step simulates an EFI boot process that writes to a single disk:
echo -n [reboot] mounting loop0 directly and modifying the filesystem...
mount -t vfat /dev/loop0 /mnt/efi
cp /var/log/messages /mnt/efi/EFI/testlog
echo done
MD5=$(md5sum /mnt/efi/EFI/testlog | awk '{print $1}')
echo [reboot] wrote testlog with md5 $MD5
echo -n [reboot] umounting loop0...
umount /mnt/efi
echo done

# now reassemble the raid and check for differences (there will be)
echo -n [reboot] reassemble the raid and run an md raid check...
assert "mdadm --assemble /dev/md1 /dev/loop0 /dev/loop1 2>&1" "mdadm: /dev/md1 has been started with 2 drives."
sleep 1
echo check > /sys/block/md1/md/sync_action
sleep 1
echo done
assert "cat /sys/block/md1/md/sync_action" "idle"
echo [reboot] mismatch_cnt: `cat /sys/block/md1/md/mismatch_cnt`
echo

# now mount the raid, and update grub.cfg like a new kernel would
echo -n [yum] simulate that we yum upgrade, writes a new grub.cfg...
mount /dev/md1 /mnt/efi
cat /boot/grub2/grub.cfg >> /mnt/efi/EFI/centos/grub.cfg
assert "md5sum /mnt/efi/EFI/centos/grub.cfg" "8ec08c5cf0eb83f4720748cc636b9036  /mnt/efi/EFI/centos/grub.cfg"
umount /mnt/efi
assert "mdadm --stop /dev/md1 2>&1" "mdadm: stopped /dev/md1"
echo done

echo

# now list what's in the first and second disk
echo -n [list] read loop0 directly...
assert_raises "fsck.fat /dev/loop0"
mount -t vfat /dev/loop0 /mnt/efi
assert_raises "md5deep -r /mnt/efi"
assert "md5sum /mnt/efi/EFI/centos/grub.cfg" "8ec08c5cf0eb83f4720748cc636b9036  /mnt/efi/EFI/centos/grub.cfg"
assert "md5sum /mnt/efi/EFI/testlog" "$MD5  /mnt/efi/EFI/testlog"
umount /mnt/efi
echo done
echo -n [list] read loop1 directly...
assert_raises "fsck.fat /dev/loop1" "1"
mount -t vfat /dev/loop1 /mnt/efi
assert_raises "md5deep -r /mnt/efi"
assert "md5sum /mnt/efi/EFI/centos/grub.cfg" "8ec08c5cf0eb83f4720748cc636b9036  /mnt/efi/EFI/centos/grub.cfg"
assert_raises "stat /mnt/efi/EFI/testlog" "1"
umount /mnt/efi
echo done

echo

# now lets just assemble the raid, repair the md raid, and run fsck again
echo -n [repair] assemble and repair the raid...
assert "mdadm --assemble /dev/md1 /dev/loop0 /dev/loop1 2>&1" "mdadm: /dev/md1 has been started with 2 drives."
sleep 1
echo repair > /sys/block/md1/md/sync_action
sleep 1
assert "cat /sys/block/md1/md/sync_action" "idle"
assert_raises "fsck -a /dev/md1"
echo done

echo

# now it should mount and be fine
echo -n [recheck] check everything again...
mount /dev/md1 /mnt/efi
assert_raises "md5deep -r /mnt/efi"
sleep 1
echo check > /sys/block/md1/md/sync_action
sleep 1
assert "cat /sys/block/md1/md/sync_action" "idle"
echo done
echo [recheck] mismatch_cnt: `cat /sys/block/md1/md/mismatch_cnt`
assert "cat /sys/block/md1/md/mismatch_cnt" "0"
umount /dev/md1

# cleanup for next run
umount /mnt/efi &> /dev/null
mdadm --stop /dev/md1 &> /dev/null
losetup -d /dev/loop0 &> /dev/null
losetup -d /dev/loop1 &> /dev/null


assert_end

