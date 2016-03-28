Spiderpig is a document metadata harvester first and foremost. It is intended for use by security professionals and pen testers. Please do not run it against sites without permission.
Spiderpig actively spiders a site, downloads all documents and parses out useful data. You can also provide a domain instead of a full URL, it will DNS brute force sub-domains before spidering each resolved name, downloading the files and doing the metadata harvesting.

Most document metadata harvesters use search results to find documents. Spiderpig was created to provide an alternative to that.

### Basic usage

**./spiderpig -u** http://www.somewebsite.com  - Spiders the provided URL, downloads documents and prints out the document creator (potentially a username) and the software used to create the document.

**./spiderpig -d somewebsite.com** - Performs sub-domain brute forcing, then spiders each resolved name. Currently the default sub-domain list is 'domains.txt' which is included with Spiderpig. This is a slightly modified 'small.txt' from dirb - https://sourceforge.net/projects/dirb/

**./spiderpig -d somewebsite.com -b mysubdomains.txt** - Specify your own subdomain text file for brute forcing.

There are also options to obey the robots.txt (or not), use a proxy server, specify the spidering depth, specify a user agent string and specify a dns server:

**-o, --obey-robots    Should we obey robots.txt? Default is true (default: True)**

**-e, --depth        Spidering depth - Think before setting too large a value (default: 2)**

**-s, --user-agent     Enter your own user agent string in double quotes!
 (default: Mozilla/5.0 (Windows NT 6.1; WOW64; rv:40.0)Gecko/20100101 Firefox/40.1)**
 
**-n, --dns-server     Provide a custom DNS server to use for subdomain lookups - Google resolver1 is the default (default:8.8.8.8)**

**-p, --proxy              Specify a proxy server**

**-r, --proxyp             Specify a proxy port**




### Dirtmode

Dirtmode is where things get a little more interesting. It is designed to find 'dirt' on your target organisation.
Currently, Dirtmode will pull out the following information from all downloaded documents:

- Email addresses
- Credit Card Numbers (Luhn/Mod10 validated)
- IP Addresses
- Keywords - See keywords.txt and add your own. This functionality is designed to find information that shouldn't be in the public domnain, for example passwords in documents, references to internal systems and administrative protocols etc. This could be edited to find whatever you like realistically. Feel free to make a request and I will endevour to add it.

When running Dirtmode, you can also generate a wordlist. This simply builds a flat text file of all words seen in all documents. This can be useful in two ways. 1) As a file for sub-domain brute forcing and 2) As a password list for remote password attacks or hash cracking. Example usage:

**./spiderpig -u http://www.somewebsite.com --dirtmode --passlist**
This will drop a 'passlist.txt' into the datestamped directory that contains all downloaded documents.

### Installation
Just run 'bundle install' from the cloned directory.

### Notes/Known issues
If you run into issues, comment out '**$stderr.reopen("/dev/null", "w")**' on line 27. This will send errors back to your console.
If you get an error about not being able to create a listener, kill java and try again. This is because the Yomu metadata module uses Apache Tika (Java) to get data. This spawns a local server for faster processing. It often does not die correctly and holds onto the port it bound to.
Tested only on OSX El Capitan with ruby 2.2.0p0 (2014-12-25 revision 49005) [x86_64-darwin14] although there is no reason why it shouldn't work on other systems.
