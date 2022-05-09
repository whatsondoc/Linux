import os, sys
import datetime
import argparse
import logging
import json
import string, random

# // Structure:

# //   Local file with json contents is the database file
# //   Program can be invoked with --start which looks for the existence of a database file
# //    - If exists: program cannot run with --start, can only be run with --resume
# //    - If not exists: program runs, creates a file with the fixed name, generates a random string, writes to database file as UUID, and waits for user input
# //   Logs are written to a shared filesystem (NFS or SMB - OS dependent)
# //    - Log file path is provided when the program runs with --logdir
# //    - Log file has a UUID which matches the database file - these must be the same, i.e. the program cannot run with a generic log file 
# //    - Program cannot run without a valid log directory

def cli():
    parser = argparse.ArgumentParser(prog='business_application.py', allow_abbrev=True, description='A simulated business application performing actions and depending on distinct components to function')
    parser.add_argument('--debug', action='store_true', help='Dump debug info')

    subparsers = parser.add_subparsers(dest='command')

    start = subparsers.add_parser('start', help='Start the [simulated] business application')
    start.add_argument('--logpath', required=True, metavar='/path/to/log/dir', type=str, default='', help='The directory path to where the log file will be created & stored')

    resume = subparsers.add_parser('resume', help='Resume the [simulated] business application')
    resume.add_argument('--logpath', required=True, metavar='/path/to/log/dir', type=str, default='', help='The directory path to the existing log file')

    # parser.add_argument('--...', metavar='', type=str, default='', help='...')

    if len(sys.argv)==1:
        parser.print_help(sys.stderr)
        sys.exit(1)

    cli_args = parser.parse_args()

    if cli_args.debug:
        print("DEBUG: " + str(cli_args))

    return cli_args

def setup_logging(cli_args, log_file_path):
    file_handler = logging.FileHandler(filename = log_file_path)
    log_handlers = [file_handler]

    # // Default logging options, including a predefined format string (noting time, user and log level) with the message
    logging.basicConfig(format = '%(asctime)s | %(name)s | %(levelname)s -->  %(message)s',
                        level = logging.INFO,
                        handlers = log_handlers
                        )

    log = logging.getLogger()

    if cli_args.debug == True:
        log.setLevel(logging.DEBUG)

    return log

def validation(cli_args, data_file_path, log_file_path):
    match_string = 'UUID'
    
    if not os.path.exists(cli_args.logpath):
        print('')
        print('The specified log path cannot be enumerated: {0}'.format(cli_args.logpath))
        print('[Terminating application]')
        print('')
        quit()

    if cli_args.command == 'start':        
        if os.path.isfile(data_file_path) == True:
            print('')
            print('An existing data file has been detected at: {0}'.format(data_file_path))
            print('[Terminating application]')
            print('')
            quit()
        
        if os.path.isfile(log_file_path) == True:
            print('')
            print('An existing log file has been detected at: {0}'.format(log_file_path))
            print('[Terminating application]')
            print('')
            quit()

    if cli_args.command == 'resume':
        if os.path.isfile(data_file_path) == False:
            print('')
            print('Cannot detect the data file at this path: {0}'.format(data_file_path))
            print('Unable to resume from state')
            print('[Terminating application]')
            print('')
            quit()
        elif os.path.isfile(data_file_path) == True:
            with open(data_file_path, 'r') as df:
                for line in df:
                    if match_string in line:
                        validate_uuid_data = line.partition(': ')[-1].lstrip()
                        validate_uuid_data = validate_uuid_data.replace('"','')
                        validate_uuid_data = validate_uuid_data.replace(',','')
        
        if os.path.isfile(log_file_path) == False:
            print('')
            print('Cannot detect the log file in the specified directory: {0}'.format(log_file_path))
            print('Unable to resume from state')
            print('[Terminating application]')
            print('')
            quit()
        elif os.path.isfile(log_file_path) == True:
            with open(log_file_path, 'r') as df:
                for line in df:
                    if match_string in line:
                        validate_uuid_log = line.partition(': ')[-1].lstrip()

        if validate_uuid_data != validate_uuid_log:
            print('')
            print('Instance UUID mismatch:')
            print('     Data File UUID  : {0}'.format(validate_uuid_data))
            print('     Log File UUID   : {0}'.format(validate_uuid_log))
            print('')
            print('[Terminating application]')
            print('')
            quit()
    
    return

def generate_uuid(length, scope):
    if scope == 'upperletters':
        input_range = string.ascii_uppercase
    elif scope == 'lowerletters':
        input_range = string.ascii_lowercase
    elif scope == 'numbers':
        input_range = string.digits
    elif scope == 'upperletters-numbers':
        input_range=string.digits + string.ascii_uppercase
    elif scope == 'lowerletters-numbers':
        input_range=string.digits + string.ascii_lowercase

    return ''.join(random.choice(input_range) for _ in range(length))

def open_data_file(data_file_path, log, log_file_path):
    start_header = '*** Starting OSBA data file ***'
    data_file_uuid = generate_uuid(8, 'upperletters-numbers')
    timestamp_start = '{:%Y-%m-%d %H:%M}'.format(datetime.datetime.now())          
    data_file_input = {}
    data_file_input['dataFile'] = []
    data_file_input['dataFile'].append({
        'instanceUUID': data_file_uuid,
        'timestampStart': timestamp_start
    })

    with open(data_file_path, 'w') as df:
        json.dump(data_file_input, df, indent=4)
        df.close()

    log.info(start_header)        
    log.info('Instance UUID     : {0}'.format(data_file_uuid))
    log.info('Timestamp         : {0}'.format(timestamp_start))
    log.info('Data File path    : {0}'.format(data_file_path))
    log.info('Log File path     : {0}'.format(log_file_path))
    log.info('-----------------------------------------')
    log.info('')

    return

def resume_data_file(data_file_path, log):
    data_file_resume_header = '>>> Resuming OSBA data file <<<'
    timestamp_resume = '{:%Y-%m-%d %H:%M}'.format(datetime.datetime.now())        

    with open(data_file_path, 'r') as df:
        data_file_contents = json.load(df)
        df.close()

    with open(data_file_path, 'w') as df:
        data_file_contents['dataFile'].append({
            'timestampResume': timestamp_resume
        })
        json.dump(data_file_contents, df, indent=4)
        df.close()

    log.info(data_file_resume_header)
    log.info('Timestamp         : {0}'.format(timestamp_resume))

    return

def clear_screen():
    os.system('cls||clear')

def menu_header():
    clear_screen()
    datetimereader_menu_header = '{:%Y-%m-%d %H:%M}'.format(datetime.datetime.now())
    print('                                                                                 ')
    print('#----------------------------------------------------------------------------#   ')
    print('                 OSBA: Our [Simulated] Business Application                      ')
    print('#----------------------------------------------------------------------------#   ')
    print('                            ' + datetimereader_menu_header + '                   ')
    print('                                                                                 ')

def home_menu():
    menu_header()
    print('     >>> HOME MENU                                                               ')
    print('                                                                                 ')
    print('         1) Add Record                                                           ')
    print('         2) Remove Record                                                        ')
    print('         3) Print All Records                                                    ')
    print('         4) Submit Query                                                         ')
    print('         5) Quit                                                                 ')
    print('                                                                                 ')
    print('                                                                                 ')
    choice = input('    Selection: ')

    return choice

def read_record_data(data_file_path):
    with open(data_file_path, 'r') as df:
        existing_records_data = json.load(df)
        df.close()
    
    return existing_records_data

def create_record():
    timestamp_add_record = '{:%Y-%m-%d %H:%M}'.format(datetime.datetime.now())    
    add_record_state_first_name = generate_uuid(random.randint(3,11), 'lowerletters')  
    add_record_state_second_name = generate_uuid(random.randint(2,15), 'lowerletters')
    add_record_state_identifier = generate_uuid(35, 'lowerletters-numbers')
    message = 'Adding new record    : {0}'.format(add_record_state_identifier)

    new_record_data = {
        'nameFirst': add_record_state_first_name,
        'nameSecond': add_record_state_second_name,
        'identifier': add_record_state_identifier,
        'timestamp': timestamp_add_record
    }

    return message, new_record_data

def update_records_data(records_data, new_record_data):
    records_data['records'].append(new_record_data)

    return records_data

def write_json_data(updated_records_data, data_file_path):
    with open(data_file_path, 'w') as df:
        json.dump(updated_records_data, df, indent=4)
        df.close()
    
    return

def add_record(data_file_path, log):
    menu_header()
    records_data = read_record_data(data_file_path)
    message, new_record_data = create_record()
    updated_records_data = update_records_data(records_data, new_record_data)
    write_json_data(updated_records_data, data_file_path)

    print(message)
    log.info(message)

    print('')
    input('Press enter to return to the home menu ...')
    #home_menu()

    return

def remove_record():
    print('')
    print('Remove Record    [Not currently supported at this time]')
    print('')
    input('Press enter to return to the home menu ...')
    #home_menu()

    return

def print_all_records(data_file_path):
    print('')
    print('Printing all records:')
    print('')
    with open(data_file_path, 'r') as df:
        read_all_records = json.load(df)
        formatted_json_data = json.dumps(read_all_records, indent=4)
        print(formatted_json_data)
        df.close()
    
    input('Press enter to return to the home menu ...')
    #home_menu()

    return

def query_record():
    print('')
    print('Submit Query     [Not currently supported at this time]')
    print('')
    input('Press enter to return to the home menu ...')
    #home_menu()

    return

def create_osba_data(data_file_path, log):
    bulk_add_record_quantity = random.randint(40, 250)
    
    with open(data_file_path, 'r') as df:
        existing_data = json.load(df)
        df.close()

    with open(data_file_path, 'w') as df:
        existing_data['records'] = []
        for _ in range(bulk_add_record_quantity):
            timestamp_bulk_add_record = '{:%Y-%m-%d %H:%M}'.format(datetime.datetime.now())
            bulk_add_state_first_name = generate_uuid(random.randint(3,11), 'lowerletters')
            bulk_add_state_second_name = generate_uuid(random.randint(2,15), 'lowerletters')
            bulk_add_state_identifier = generate_uuid(35, 'lowerletters-numbers')

            existing_data['records'].append({
                'nameFirst': bulk_add_state_first_name,
                'nameSecond': bulk_add_state_second_name,
                'identifier': bulk_add_state_identifier,
                'timestamp': timestamp_bulk_add_record
            })
        json.dump(existing_data, df, indent=4)
        df.close()
    
    log.info('Initial bulk creation of OSBA data')
    log.info('{0} records added'.format(bulk_add_record_quantity))

def main():
    cli_args = cli()

    data_file_name = 'osba_data_file.dat'
    log_file_name = 'osba_log_file.txt'
    data_file_path = os.path.join(os.getcwd(), data_file_name)
    log_file_path = os.path.join(cli_args.logpath, log_file_name)

    validation(cli_args, data_file_path, log_file_path)
    log = setup_logging(cli_args, log_file_path)

    if cli_args.command == 'start':
        open_data_file(data_file_path, log, log_file_path)
        # data_file_uuid = generate_uuid(length=8, type='upperletters-numbers')

        create_osba_data(data_file_path, log)

    elif cli_args.command == 'resume':
        resume_data_file(data_file_path, log)
    
    while(True):
        choice = home_menu()
        if choice == '1':
            log.info('Option selected by user: {0}'.format(choice))
            add_record(data_file_path, log)
        elif choice == '2':
            log.info('Option selected by user: {0}'.format(choice))
            remove_record()
        elif choice == '3':
            log.info('Option selected by user: {0}'.format(choice))
            print_all_records(data_file_path)
        elif choice == '4':
            log.info('Option selected by user: {0}'.format(choice))
            query_record()
        elif choice == '5':
            log.info('User initiated program exit')
            break
        else:
            log.info('Option selected by user: {0}'.format(choice))
            log.info('Unrecognised option: {0}'.format(choice))
            print('Unrecognised option: {0}'.format(choice))
            print('')
            input('Press enter to return to the home menu ...')
            #home_menu()

    log.info('')
    log.info('[Terminating application]')
    log.info('') 


if __name__ == '__main__':
    main()