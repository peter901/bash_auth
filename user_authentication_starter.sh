#!/bin/bash
## to be updated to match your settings
PROJECT_HOME="."
credentials_file="$PROJECT_HOME/data/credentials.txt"
logged_in_file="$PROJECT_HOME/data/log.logged_in"

# Function to prompt for credentials
get_credentials() {
    read -p 'Username: ' user
    read -rs -p 'Password: ' pass
    echo
}

generate_salt() {
    openssl rand -hex 8
    return 0
}

## function for hashing
hash_password() {
    # arg1 is the password
    # arg2 is the salt
    password=$1
    salt=$2
    # we are using the sha256 hash for this.
    echo -n "${password}${salt}" | sha256sum | awk '{print $1}'
    return 0
}

check_existing_username() {
    local username=$1
    ## verify if a username is already included in the credentials file
    while IFS=: read -r user hash salt role logged; do
        if [ $user = $username ]; then
            return 1
        fi
    done <$credentials_file
    return 0
}

## function to add new credentials to the file
register_credentials() {
    clear
    # arg1 is the username
    # arg2 is the password
    # arg3 is the fullname of the user
    # arg4 (optional) is the role. Defaults to "normal"

    local username=$1
    local password=$2
    local fullname=$3

    ## call the function to check if the username exists
    check_existing_username $username

    #TODO: if it exists, safely fails from the function.
    if [[ $? -eq 1 ]]; then
        echo "User ${username} already exists"
        return 1
    fi

    ## retrieve the role. Defaults to "normal" if the 4th argument is not passed
    if [ -z "$4" ]; then
        local role='normal'
    else
        local role=$4
    fi

    ## check if the role is valid. Should be either normal, salesperson, or admin
    if [ $role != 'normal' -a $role != 'salesperson' -a $role != 'admin' ]; then
        echo "Invalid role ${role} entered"
        return 1
    fi

    ## first generate a salt
    salt=$(generate_salt)
    ## then hash the password with the salt
    hashed_pwd=$(hash_password $password $salt)
    ## append the line in the specified format to the credentials file (see below)
    ## username:hash:salt:fullname:role:is_logged_in
    echo "${username}:${hashed_pwd}:${salt}:${fullname}:${role}:0" >>$credentials_file
    echo "User ${username} created successfully ...!"
    return 0
}

# Function to verify credentials
verify_credentials() {
    clear
    ## arg1 is username
    ## arg2 is password
    local username=$1
    local password=$2
    ## retrieve the stored hash, and the salt from the credentials file
    # if there is no line, then return 1 and output "Invalid username"
    check_existing_username $username

    if [[ $? -eq 0 ]]; then
        echo "Invalid username ${username}"
        return 1
    fi

    ## compute the hash based on the provided password
    hashed_pwd=$(hash_password $password $salt)

    ## compare to the stored hash
    ### if the hashes match, update the credentials file, override the .logged_in file with the
    ### username of the logged in user
    if [[ $hashed_pwd = $hash ]]; then
        login $username
        echo $username >$logged_in_file
        echo "User ${username} successfully logged in"
        return 0
    else
        echo "Invalid password"
        return 1
    fi

    ### else, print "invalid password" and fail.
}

login() {
    local user=$1
    while IFS=: read -r username hash salt fullname role logged; do
        if [[ $user = $username ]]; then
            search_string="$username:$hash:$salt:$fullname:$role:$logged"
            replace_string="$username:$hash:$salt:$fullname:$role:1"

            sed -i "s/$search_string/$replace_string/" $credentials_file
            return 0
        fi
    done <$credentials_file
}

log_out() {
    local user=$(cat "$logged_in_file")
    #TODO: check that the .logged_in file is not empty
    # if the file exists and is not empty, read its content to retrieve the username
    # of the currently logged in user

    # then delete the existing .logged_in file and update the credentials file by changing the last field to 0

    while IFS=: read -r username hash salt fullname role logged; do
        if [[ $user = $username ]]; then
            search_string="$username:$hash:$salt:$fullname:$role:$logged"
            replace_string="$username:$hash:$salt:$fullname:$role:0"

            sed -i "s/$search_string/$replace_string/" $credentials_file
            rm $logged_in_file
        fi
    done <$credentials_file

    clear

    echo "You have successfully logged out....!"
    return 0
}

## Create the menu for the application
# at the start, we need an option to login, self-register (role defaults to normal)
# and exit the application.
menu() {
    echo "Welcome to the authentication system."
    echo "1. login"
    echo "2. self-register"
    echo "3. exit"
    echo
    read -p "Select an option [1-3]: " option
}

logged_in_menu() {
    get_user
    get_role

    echo "You are logged in as ${username}"

    if [[ $role = 'admin' ]]; then
        echo "2. Create account"
    fi

    echo "3. exit"
    echo "4. logout"
    echo
    read -p "Select an option: " option
}

get_user() {
    username=$(cat "$logged_in_file")
}
get_role() {
    user=$(cat "$logged_in_file")
    while IFS=: read -r username hash salt fullname role logged; do
        if [[ $user = $username ]]; then
            return
        fi
    done <$credentials_file
}

# After the user is logged in, display a menu for logging out.
# if the user is also an admin, add an option to create an account using the
# provided functions.

# Main script execution starts here
#echo "Welcome to the authentication system."
get_menu() {
    if [[ -f "$logged_in_file" ]]; then
        logged_in_menu
    else
        menu
    fi
}

get_menu

while [[ true ]]; do
    if [[ $option -eq 1 ]]; then
        get_credentials
        verify_credentials $user $pass
    elif [[ $option -eq 2 ]]; then
        read -p "Enter your username: " username
        read -p "Enter your fullname: " fullname
        read -rs -p "Enter your password: " password
        echo
        read -p "Enter role (admin , salesperson, normal - default normal): " role

        register_credentials "${username}" "${password}" "${fullname}" "${role}"
    elif [[ $option -eq 3 ]]; then
        echo
        echo "Good-bye...!"
        exit 0
    elif [[ $option -eq 4 ]]; then
        log_out
    else
        clear
        echo "Invalid choice ${option} selected - try again"
    fi

    get_menu
done
#### BONUS
#1. Implement a function to delete an account from the file
