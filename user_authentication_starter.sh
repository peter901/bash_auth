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
    username=$1
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

    username=$1
    password=$2
    fullname=$3

    ## call the function to check if the username exists
    check_existing_username $username

    #TODO: if it exists, safely fails from the function.
    if [[ $? -eq 1 ]]; then
        echo "User ${username} already exists"
        return 1
    fi

    ## retrieve the role. Defaults to "normal" if the 4th argument is not passed
    if [ -z "$4" ]; then
        role='normal'
    else
        role=$4
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
    username=$1
    password=$2
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
    user=$1
    while IFS=: read -r username hash salt fullname role logged; do
        if [[ $user = $username ]]; then
            search_string="$username:$hash:$salt:$fullname:$role:$logged"
            replace_string="$username:$hash:$salt:$fullname:$role:1"

            sed -i "s/$search_string/$replace_string/" $credentials_file
            return 0
        fi
    done <$credentials_file
}

logged_in_menu() {
    echo "You are logged in as ${username}"
    echo "1. l"
    echo "2. Create account"
    echo "3. exit"
    echo
    read -p "Select an option [1-3]: " option
}

logout() {
    user=$1
    #TODO: check that the .logged_in file is not empty
    # if the file exists and is not empty, read its content to retrieve the username
    # of the currently logged in user

    # then delete the existing .logged_in file and update the credentials file by changing the last field to 0

    while IFS=: read -r username hash salt role logged; do
        if [[ $user = $username ]]; then
            search_string="$username:$hash:$salt:$role:1+"
            replace_string="$username:$hash:$salt:$role:0"

            sed -i "s/$search_string/$replace_string/" $credentials_file
        fi
    done <$credentials_file
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

# After the user is logged in, display a menu for logging out.
# if the user is also an admin, add an option to create an account using the
# provided functions.

# Main script execution starts here
#echo "Welcome to the authentication system."
menu

while [[ true ]]; do
    if [[ $option -eq 1 ]]; then
        get_credentials
        verify_credentials $user $pass
    elif [[ $option -eq 2 ]]; then
        read -p "Enter your username: " username
        read -p "Enter your fullname: " fullname
        read -rs -p "Enter your password: " password
        echo
        register_credentials "${username}" "${password}" "${fullname}"
    elif [[ $option -eq 3 ]]; then
        echo
        echo "Good-bye...!"
        exit 0
    else
        clear
        echo "Invalid choice ${option} selected - try again"
    fi

    menu
done
#### BONUS
#1. Implement a function to delete an account from the file
