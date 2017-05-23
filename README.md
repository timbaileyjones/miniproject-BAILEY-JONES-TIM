# miniproject-BAILEY-JONES-TIM

## Prequisites
 * Installation of 'awscli'
 * Python interpreter (both 2 or 3 will work)
 * ssh/rsync 
 * working AWS account with credentials established in one of the following places
   * 'aws configure' 
   * exported AWS_* environment variables
     (See set-amazon-environment.sh for sample)
   * a *.pem file from your AWS account present in this directory
   * The *.pem file must be named in the install-webserver.sh file as KEY_FILE, 
     but without the *.pem suffix.  The one from my environment is included as a sample,
     but will only work with my AWS credentials.

## Usage
 *  ./install-webserver.sh
 *  ./destroy-webserver.sh  # optional

## Notes
 * The install-webserver.sh script saves 2 ids to hidden dot-files, so that the 
   destroy-webserver.sh script can remove these ids at a later time.
   Appending (>>) is used instead of writing (>) so that you can start multiple
   servers, and then delete all of them in one pass. The IDs that are saved are for:

    * .instance_ids - Amazon VM instance IDs
    * .security_group_ids - Security Group IDs

   The delete-webserver.sh script deletes these dot-files once the aws commands that
   delete the IDs have run successfully. 

   The choice of local-dotfiles means that you must terminate the instances from the same
   workspace as you installed them.  A better place to store these IDs might be Amazon's
   parameter store. The advantage would be the ability to delete the webservers from a different
   workspace or computer than the one used to install the webservers.

 * Instead of waiting an arbitary period of time for the SSHD daemon to come up,
   the install-webserver.sh relies on a short python script to check the availability of
   the sshd port, once per second, up to 30 seconds.  I was NOT satisfied with hard-coding
   in a 20-second wait at that point in the script.

   I could have used ansible's wait_for module to the same thing, but I didn't want to
   introduce a dependency on ansible just for this one task.  I looked to see if the awscli
   could have done that for me, but I didn't find that functionality there.

 * The install-webserver.py script also checks the installation by fetching the index.html
   page via 'curl' and checking for the word: "Automation".
