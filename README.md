![PIV icon](images/piv.png)
# PIV - Post Implementation Verifier

## TABLE OF CONTENTS

- [Overview](#OVERVIEW)
- [Prerequisites](#PREREQUISITES)
- [Installation](#INSTALLATION)
- [How PIV Works](#HOW-PIV-WORKS)
- [Command Syntax](#COMMAND-SYNTAX)
- [Example](#EXAMPLE)
- [List of PIV Commands](#List-of-PIV-commands)
- [Built-in functions](#Built-in-functions)


## OVERVIEW
PIV is a REXX procedure that you can run in batch to verify that
the system is in the state you expect it to be after making a change.

How is this better than simply running SDSF in batch?
1. There is less clutter because there is no SDSF screen rendering
2. You can programmatically examine the SDSF command response lines
   (or file content) and set an appropriate condition code.

Because of this it can be used as an audit tool to verify, for example,
that PARMLIB members contain the correct values, or system software is
at the expected maintenance level etc. This is much quicker than doing
a manual audit check on possibly many systems.

PIV can be used to:
- issue z/OS commands and Unix command and verify that the response is as expected
- read z/OS datasets or Unix files and verify that they contain the expected strings
- read JES sysout datasets (including those in the job executing the PIV REXX) and
  verify that the content is as expected.

The result of this checking is indicated in the job step condition code
of the step running the PIV EXEC.
Usually COND CODE 0 means "all good" and COND CODE 4 means "PIV failed" -
but you can set whatever condition code you want.
This enables you to take further automated action
depending on the condition code.

PIV also prints a log of its own activity, including all commands issued and
responses received, which makes for an excellent audit artifact.

## PREREQUISITES

1. To fully benefit from PIV you will need appropriate RACF authorisations to:
  - Issue SDSF console commands
  - Read SDSF spool files
  - Read Unix System Services files
  - Issue Unix System Services commands

  However, you will still be able to use a subset of its features
  (for example, examining your own SDSF job output) if your site
  allows that.

## INSTALLATION

1. Install the following REXX file into your RECFM=VB LRECL=255
   REXX library (FB80 is sooooo last century):

   | File    | Description
   | ----    | -----------
   | PIV     | The PIV processor



## HOW PIV WORKS

The PIV REXX procedure uses the SDSF REXX interface to:
- Extract information from SDSF
- Read specified spool files
- Issue z/OS commands

It can also:
- Issue Unix commands and retrieve the resulting output
- Read z/OS datasets and Unix files

As each command is executed, the response (e.g. console command output,
or file contents) is stored in REXX `line.n` variables for subsequent
testing (for example, by `ASSERT` commands).

The PIV SDSF commands are pretty much identical to the SDSF primary commands that
everyone is familiar with, so the learning curve is minimal.

However, there are some additional PIV commands that can be used to verify
the system state (`ASSERT`, `IF` and `USING`, `PASSIF`, `FAILIF`) and set the
job step condition code accordingly.

The PIV REXX procedure prints a simple report (to SYSTSPRT) of its activities which include:
- The command issued (e.g `/D ETR`, or `READ SYS1.PARMLIB(IEASYS00)`, etc)
- The command response received (or the file contents read)
- The result of any verification commands (e.g. `ASSERT`)

At the end of the report, a simple one-line statement is written to indicate
success or failure of the PIV process:

- Result: PIV successful
- Result: PIV failed with maxrc=*n*



## COMMAND SYNTAX

All commands and tests are read from DD INPUT.

The syntax rules for the input file are:

1. CONTINUATIONS

   A line continuation is indicated by a comma (,) as
   the last non-blank character (i.e. the same as a
   REXX continuation).

2. COMMENTS

   Lines with a blank in column 1 are treated as
   comments and are simply printed to SYSTSPRT as-is.

3. COMMANDS

   A line NOT beginning with a blank in column 1 is a command to
   be processed. All commands are case-insensitive.
   The response from each command is returned in REXX
   variables called `line.n` where n ranges from 1 to the number
   of response lines and `line.0` contains the number of response lines.


## EXAMPLE

This example checks the health of a fictitious software product:

    //PIVTEST  JOB ,,CLASS=A,MSGCLASS=X,NOTIFY=&SYSUID
    //PIV     EXEC PGM=IKJEFT1A,PARM='%PIV'
    //SYSEXEC   DD DISP=SHR,DSN=your.exec.lib
    //SYSTSPRT  DD SYSOUT=*
    //INPUT     DD *
      Ensure the product started tasks are all running. We expect
      that both MYSTCA and MYSTCB are up:

    prefix MY*
    da
    assert find('MYSTCA')
    assert find('MYSTCB')

      Check that the software version is correct and is licensed:

    select mystca sysprint
    assert  find('MY0001I','VERSION', '1.0.39')
    assert \find('MY0002E','LICENSE EXPIRED')
    assert \find('MY0003W','LICENSE ABOUT TO EXPIRE')

      Check that the software configuration settings are correct:

    read SYS1.PARMLIB(MYCONFIG)
    assert isPresent('STC=MYSTCA')

      Check that the software is responding to commands:

    /F MYSTCA,DISPLAY,VERSION
    assert isPresent('MY0001I')

      Just for shiggles, check that the Server Time Protocol is active:

    /D ETR
    using keyword . . mode .
    passif keyword = 'SYNCHRONIZATION' & mode = 'STP'
    using . . . . keyword level .
    passif keyword = 'STRATUM' & level < 3
    /*





## List of PIV Commands

All commands must start in column 1 and are case insensitive.
The uppercase letters are the minimum abbreviation for each of the commands shown below.

| Command | Description |
| ------- | ----------- |
| [**HELP**](#HELP) | Display this help information (in batch) |
| [/*zoscommand*](#zoscommand) | Issue a z/OS command (e.g. /D ETR) |
| [**R**eply *msgno* *replytext*](#Reply-msgno-replytext) | Reply to a particular WTOR (identified by message number) after a z/OS command is issued |
| [**PRE**fix \[*jobname*\]](#PREfix-jobname) | Filter SPOOL files by job name. Reset the filter by omitting the job name |
| [**OWN**er \[*userid*\]](#OWNer-userid) | Filter SPOOL files by owner name. Reset the filter by omitting the owner name |
| [**SYS**name \[*sysname*\]](#SYSname-sysname) | Filter SPOOL files by system name. Reset the filter by omitting the system name |
| [**DEST** \[*destname*\]](#DEST-destname) | Filter SPOOL files by destination name. Reset the filter by omitting the destination name |
| [**SORT** sortspec](#SORT-sortspec) | Set the column sorting order for tabular output from an SDSF primary command (DA, I, O, etc)
| [*sdsfcommand*](#sdsfcommand) | Issue an SDSF primary command (e.g. DA, I, O, etc) - optionally filtered by prior `PREFIX`, `OWNER`, `SYSNAME` and `DEST` commands |
| [**?**](#?) | List the spool datasets for this job. You must first issue an SDSF primary command (DA, I, O, etc) |
| [**S**elect *jobname* \[*sysoutdd* \[*stepname* \[*procstep*\]\]](#Select-jobname-sysoutdd-stepname-procstep) | Read the specified JES SPOOL dataset(s) for a job into REXX `line.n` stem variables. The datasets to be read can optionally be filtered by *sysoutdd* etc). You must first issue an SDSF primary command (DA, I, O, etc) |
| [**USS** *usscommand*](#USS-usscommand) | Issue a USS command (e.g. cat /etc/profile) and capture the output into REXX `line.n` stem variables |
| [**READ** {*dsn* \| *ddname* \| *pathname*}](#READ-dsn--ddname--pathname) | Read a dataset or PDS member, a DD name, or a Unix file into REXX `line.n` stem variables |
| [**SET** *var* **=** *value*](#SET-var--value) | Set a REXX variable (usually, an SDSF special variable such as ISFPRTDSNAME) prior to issuing an SDSF export command (XD, XDC, XF, XFC) |
| [**XD**  *jobname* \[*sysoutdd* \[*stepname* \[*procstep*\]\]](#XD-jobname-sysoutdd-stepname-procstep)  | Export and append the specified JES sysout dataset to a dynamically allocated output dataset (identified by the ISFPRTDSNAME REXX variable) |
| [**XDC** *jobname* \[*sysoutdd* \[*stepname* \[*procstep*\]\]](#XDC-jobname-sysoutdd-stepname-procstep) | Same as XD but Close the dynamically allocated output dataset afterwards |
| [**XF**  *jobname* \[*sysoutdd* \[*stepname* \[*procstep*\]\]](#XF-jobname-sysoutdd-stepname-procstep)  | Export and append the specified JES sysout dataset to a pre-allocated output DD name (identified by the ISFPRTDDNAME REXX variable) |
| [**XFC** *jobname* \[*sysoutdd* \[*stepname* \[*procstep*\]\]](#XFC-jobname-sysoutdd-stepname-procstep) | Same as XF but Close the pre-allocated output DD name afterwards |
| [**SH**ow **?**](#SHOW-) | Display the gamut of column names for the most recently issued SDSF primary command (DA, I, O, etc)  |
| [**SH**ow *column* \[*column* ...\]](#SHOW-column-column-) | Display the values in just the specified columns (after issuing an SDSF primary command (DA, I, O, etc) |
| [**SH**ow **ON**](#SHOW-ON) | Enable automatic display of command responses |
| [**SH**ow **OFF**](#SHOW-OFF) | Suppress display of command responses |
| [**SH**ow](#SHOW) | Display the response lines for the previous command (even if automatic display is suppressed)|
| [**SH**ow *nnn*](#SHOW-nnn) | Limit command response output to *nnn* lines |
| [**SH**ow *heading*\[,*m*\[,*n*\]\]](#SHOW-headingmn) | Display a command response heading of *heading*, and limit command response output to lines *m* to *n* |
| [**SH**ow '*word* \[*word* ...\]'](#SHOW-word-word-) | Display only those command response lines at contain at least one of the specified words |
| [**ASSERT** *expression*](#ASSERT-expression) | Evaluate the REXX expression *expression* and set return code (rc) 0 if true, or 4 if false |
| [**IF** *expression* **THEN** rc **=** *n*; **ELSE** ...](#if-expression-then-rc--n--else-) | Evaluate the REXX expression *expression* and set rc to a user-specified return code *n* |
| [**USING** *template*](#USING-template) | Define a REXX parsing template for use by the `PASSIF` and `FAILIF` commands |
| [**PASSIF** *expression*](#PASSIF-expression) | Set return code 0 if a response line is found where the *expression* evaluates to 1 (true), else sets return code 4 |
| [**FAILIF** *expression*](#FAILIF-expression) | Set return code 4 if a response line is found where the *expression* evaluates to 1 (true), else sets return code 0 |

### HELP

Prints this help information in batch.

### /*zoscommand*

Any command prefixed with a `/` character is submitted to z/OS
for execution as an operator command. For example,

     /D ETR

You will need RACF authorisation for this to be successful.

### Reply *msgno* *replytext*

If `*nn msgno` is found in the command response then reply automatically by issuing:

    /R nn,replytext

You can specify many `REPLY` commands and the first matching *msgno* will be actioned.

### PREfix [*jobname*]

Filter SPOOL files by job name. Reset the filter by omitting the job name.

### OWNer [*userid*]

Filter SPOOL files by owner name. Reset the filter by omitting the owner name.

### SYSname [*sysname*]

Filter SPOOL files by system name. Reset the filter by omitting the system name.

### DEST [*destname*]

Filter SPOOL files by destination name. Reset the filter by omitting the destination name.

### **SORT** sortspec

Set the column sorting order for tabular output from an SDSF primary command (DA, I, O, etc).
You must enter column names rather than column titles (e.g. SORT DATEE D TIMEE D). 
Issue the [SHOW ?](#show-?) command to list the gamut of column names after you 
have selected the SDSF primary command (DA, I, O etc).

### *sdsfcommand*

Issue an SDSF primary command (`DA`, `O`, `H`, `I`, `ST`, `PS`, etc). The response
is stored in `line.n` REXX variables. Only a subset of the columns
is returned, but you can adjust this by updating the PIV REXX
procedure to set the `g.0COLS.` variables as required.

### ?

List spool datasets for a job (when issued after DA, O, H, I or ST primary command).

### Select *jobname* [*sysoutdd* [*stepname* [*procstep*]]]

This is a PIV command to read the sysout of the
specified jobname into the `line.n` variables - after you have issued
an SDSF primary command (DA, O, I etc).

You can refine the sysout to be selected by
sysoutdd, step name, and proc step name.

### USS *usscommand*

This is a PIV command to issue a Unix System Services
shell command and retrieve the command output into `line.n` variables.

For example:

    USS cat /etc/profile

### READ {*dsn* | *ddname* | *pathname*}

This is a PIV command to read the contents of the
specified dataset into the `line.n` variables.

If `dsn` contains a `/` then it is treated as a (case-sensitive)
Unix path name. The content of the file will be
converted to EBCDIC (IBM-1047) if necessary.

If `dsn` contains a `.` then it is treated as a (case-insensitive)
fully qualified dataset name that will be
dynamically allocated.

Otherwise it is assumed to
be the name of a pre-allocated DD in your JCL.

For example,

| Command                     | Description                                      | 
| -------                     | -----------                                      |
| read sys1.parmlib(ieasys00) | Reads the IEASYS00 member of SYS1.PARMLIB        |
| read /etc/profile           | Reads the contents of the Unix /etc/profile file |
| read MYDD                   | Reads the dataset allocated as DD: MYDD          |


### SET *var* = *value*

This is a PIV command to set an SDSF/REXX interface special variable.

The complete list of valid variables is described in
"SDSF Operation and Customization" (manual SA23-2274)
in Table 180 "Special REXX Variables".

Some useful ones (when using `XD`, `XDC`, `XF`, or `XFC`) are:

| Variable        | Meaning                           |
| --------        | -------                           |
| ISFPRTDDNAME    | Export DD name (for XF/XFC)       |
| ISFPRTDSNAME    | Export data set name (for XD/XDC) |
| ISFPRTDISP      | Disposition (NEW/OLD/SHR/MOD)     |
| ISFPRTBLKSIZE   | Default 3120 (27994 is better)    |
| ISFPRTLRECL     | Default 240                       |
| ISFPRTRECFM     | Default VBA                       |
| ISFPRTSPACETYPE | Default BLKS                      |
| ISFPRTPRIMARY   | Default 500                       |
| ISFPRTSECONDARY | Default 500                       |

### XD *jobname* [*sysoutdd* [*stepname* [*procstep*]]

Export and append the sysout of the specified jobname to
the dataset specified in REXX special variable
ISFPRTDSNAME (see the [SET](#SET-var--value) command above).

You can refine the sysout to be selected by
sysoutdd, step name, and proc step name.

You must have already issued either `DA`, `I`, `H`, `O` or `ST`
before you can export spool files. 

For example, 

| Command                       | Description | 
| -------                       | ----------- |
| o<br/>xd myjob                | Displays the SDSF output panel columns (subject to filtering by `PREFIX` etc)<br/>Reads all output spool datasets from MYJOB |
| xd myjob sysprint             | Reads only SYSPRINT output from all steps of MYJOB |
| xd myjob sysprint asmlink     | Reads only SYSPRINT output from step ASMLINK of MYJOB |
| xd myjob sysprint asmlink asm | Reads only SYSPRINT output from procstep ASM of step ASMLINK of MYJOB |

### XDC *jobname* [*sysoutdd* [*stepname* [*procstep*]]

This is the same as `XD` command except that the output
dataset is also Closed.

### XF *jobname* [*sysoutdd* [*stepname* [*procstep*]]

Export and append the sysout of the specified jobname to
the pre-allocated DD specified in REXX special
variable ISFPRTDDNAME (see the [SET](#SET-var--value) command above).

You can refine the sysout to be selected by
sysoutdd, step name, and proc step name.

You must have already issued either `DA`, `I`, `H`, `O` or `ST`
before you can export spool files. 

### XFC *jobname* [*sysoutdd* [*stepname* [*procstep*]]
This is the same as `XF` command except that the output
ddname is also Closed.

### SHOW ?
List the possible column names for the
SDSF primary command last issued (e.g. DA, O, etc)

For example, to list all the available column names for the
DA command:

    DA
    SHOW ?

This is a convenience command so that you don't have to refer
to the manual.

### SHOW *column* [*column* ...]
Display specific columns (for example, JNAME,
JOBID, PNAME). Use [SHOW ?](#show-?) to list all the
valid column names that you can specify for a
particular ISPF panel (DA, O, ST, etc).

### SHOW ON
Automatically print command output. This is the default.

### SHOW OFF
Suppress printing of command output.

### SHOW
Display either the contents of the default columns appropriate for
the SDSF primary command last issued or the current
contents of the `line.n` variables.

This is useful when you have suppressed
displaying responses (using [SHOW OFF](#show-off)) and want to display
the response for a particular command.

### SHOW *n*
Limit the acquired output to *n* lines maximum. The default is 1000
lines. This applies to output from all commands (i.e. z/OS command
output, USS commands, and lines read from datasets or files). It 
essentially limits the number of `line.n` stem variables used.

### SHOW *heading*[,*m*[,*n*]]
Prints the heading text followed by lines with
line numbers between *m* and *n*. The
default is to print ALL lines. A negative number
is relative to the last line, so for example:

    SHOW last few lines,-5

...will print the heading `LAST FEW LINES` followed
by the last 5 lines of output.

### SHOW '*word* [*word* ...]'

Prints only output lines that contain at least one of the
specified words.

This is useful when you only want to see messages
relating to a limited subject, for example:

    show 'LICENSE EXPIRE ERROR INVALID ABEND'

### ASSERT *expression*

The REXX expression *expression* is evaluated and if true then the
return code is set to 0 (pass), else the return
code is set to 4 (fail).

The test expression can be any expression that is
valid after a REXX `if` statement. For example,

    ASSERT isPresent('SOMETHING')

      or

    ASSERT find('SOMETHING')

...means:

"Set return code 0 if the string 'SOMETHING' is
present in the command response, else set return code 4"

### IF *expression* THEN rc = *n* [; ELSE ...]

This is similar to `ASSERT` but lets you set whatever return code
you want. Note that the PIV step will exit with the **highest**
return code you set by any of the `IF`, `ASSERT`, or `FAILIF`
PIV commands.

The `IF` command has exactly the same syntax as the REXX `if`
statement. The ASSERT example above could be
equivalently written as:

  if \isPresent('SOMETHING') then rc = 4

...which means:

"If the string 'SOMETHING' is not (\) present in
the command response then set return code 4, else set return
code 0"

The ELSE clause is rarely needed and is only included
for completeness.


### USING *template*
### PASSIF *expression*
### FAILIF *expression*

You can use a combination of either `USING` and `PASSIF`, or
`USING` and `FAILIF` to check for a response value that
may vary from time to time (i.e. is not simply a
constant string) and therefore needs to be
extracted from the command response and assigned to a REXX
variable in order to test it.

- USING  sets the parsing template to be applied
  to each line of the command response. The *template*
  can be anything that is valid after a REXX
  `parse var line.n` statement.

- PASSIF sets the return code to 0 if the REXX
  *expression* on PASSIF evaluates to 1 (true), or 4 if the
  expression evaluates to 0 (false).

- FAILIF sets the return code to 4 if the REXX
  *expression* on FAILIF evaluates to 1 (true), or 0 if the
  expression evaluates to 0 (false).

For example, you may want to verify that spool
usage is acceptable by checking the output of a
`$DSPOOL` JES command, which may look like:

    $HASP893 VOLUME(SPOOL1)  STATUS=ACTIVE,PERCENT=23
    $HASP646 23.6525 PERCENT SPOOL UTILIZATION

To verify this, you could use:

    /$DSPOOL
    USING msgno percent .
    PASSIF msgno = '$HASP646' & percent < 80

This will cause each line of the command response to be
parsed (using `parse var line.n msg percent .`) causing
the first and second words of each
line to be assigned to the REXX variables `msgno`
and `percent` respectively. If a line is found
where `msgno` is '$HASP646' and the `percent`
value is less than 80, then return code 0 is set.
If no line containing $HASP646 is found, or the
percent value is more than 80, then return code
4 is set.

The processing of command response lines stops
when the expression on `PASSIF` or `FAILIF` is true.

Alternatively, you could examine the $HASP893
message (which has a lower resolution percentage):

    /$DSPOOL
    USING msgno . 'PERCENT='percent .
    PASSIF msgno = '$HASP893' & percent < 80

This will cause each line of the command response to be
parsed and the message number and percent
value to be extracted. Processing is similar to
the previous example.


# Built-in functions

There are a few convenience functions in the PIV
REXX procedure that you can use on the `ASSERT`, `IF`,
`PASSIF` and `FAILIF` commands if you want.

You can, of course, use any of the REXX built-in
functions too. For example:

    subword(line.3,2) = 'HI'


  | Function                   | Description                                                         |
  | --------                   | -----------                                                         |
  | find(*str*)                | Returns 1 if *str* is found in any line           (else returns 0)  |
  | find(*str*[,*str* ...])    | Returns 1 if ALL strings are found on one line    (else returns 0)  |
  | isPresent(*str*)           | Returns 1 if *str* is found in any line           (else returns 0)  |
  | isPresent(*str*,line.*n*)  | Returns 1 if *str* is found in line.*n*           (else returns 0)  |
  | isAbsent(*str*)            | Returns 1 if *str* is not found in any line       (else returns 0)  |
  | isAbsent(*str*,line.*n*)   | Returns 1 if *str* is not found in line.*n*       (else returns 0)  |
  | isNum(*str*)               | Returns 1 if *str* is an integer                  (else returns 0)  |
  | isWhole(*str*)             | Returns 1 if *str* is an integer                  (else returns 0)  |
  | isHex(*str*)               | Returns 1 if *str* is non-blank hexadecimal       (else returns 0)  |
  | isAlpha(*str*)             | Returns 1 if *str* is alphanumeric                (else returns 0)  |
  | isUpper(*str*)             | Returns 1 if *str* is upper case alphabetic       (else returns 0)  |
  | isLower(*str*)             | Returns 1 if *str* is lower case alphabetic       (else returns 0)  |
  | isMixed(*str*)             | Returns 1 if *str* is mixed case alphabetic       (else returns 0)  |
