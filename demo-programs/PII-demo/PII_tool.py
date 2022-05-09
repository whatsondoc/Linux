import re, os, subprocess

name_file = '.NAME'
with open(name_file, 'r') as nf:
    name_data = nf.read()
    nf.close()

dir_path = r'/mnt/nfs/rockyheights'
# mount_dir = r'/path/to/mount'
# dir_name = 'dataset'
# dir_path = os.path.join(mount_dir, dir_name)
# dir_path = os.path.join(os.getcwd(), dir_name)

output = 'BREACH---PII_matched_data.txt'
metadatalog = 'metadata_log.txt'

print('')
print('--------------------')
print('PII Scan: [Starting]')
print('--------------------')

# output_file = open(output, 'a')
# metadata_log = open(metadatalog, 'a')

for root, dirname, files in os.walk(dir_path):
    for scan_file in files:
            filepath = os.path.join(root, scan_file)
            with open(filepath, 'r') as f:
                for line in f:
                    if line in name_data:
                        print('*** PII Match: {0}    {1}'.format(line, filepath))
                        with open(output, 'a') as out:
                            out.write('*** PII Match: {0}'.format(line))
                            out.close()

                        ## Add Custom Metadata:
                        # process_state = subprocess.run(['', '', '', '', f])
                f.close()

# output_file.close()
# metadata_log.close()

print('--------------------')
print('PII Scan: [Complete]')
print('--------------------')
print('')