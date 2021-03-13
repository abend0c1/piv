/*REXX*****************************************************************
**                                                                   **
** NAME     - PIV                                                    **
**                                                                   **
** TITLE    - POST IMPLEMENTATION VERIFIER                           **
**                                                                   **
** FUNCTION - This uses the SDSF REXX interface to issue commands,   **
**            check the response text, and set a user specified      **
**            return code based on the command output.               **
**                                                                   **
**            It is meant to be used to perform a sanity check after **
**            implementing a system change, but it can be used for   **
**            much more than that.                                   **
**                                                                   **
**            It is a vast improvement over simply running SDSF in   **
**            batch because:                                         **
**              1. It reduces clutter because no 3270 screen         **
**                 renderings appear.                                **
**              2. You can perform some conditional logic and set    **
**                 a step condition code accordingly.                **
**                                                                   **
**            It supports a number of commands including those that  **
**            check the contents of sysout datasets or z/OS datasets,**
**            display SDSF panel content, and issue z/OS console     **
**            commands.                                              **
**                                                                   **
**            All commands must begin in column 1. If column 1 is    **
**            a blank then the entire line is considered to be a     **
**            comment and is simply copied to the output report.     **
**                                                                   **
**            When each command is issued, the command output is     **
**            stored in REXX variables called `line.n` (where `n` is **
**            the line number). Command output is normally printed   **
**            to the output report, but you can suppress (or limit)  **
**            this output if you wish.                               **
**                                                                   **
**            When issuing z/OS commands, you can provide an auto-   **
**            matic reply depending on the command response. This    **
**            is useful for starting system traces, for example.     **
**                                                                   **
**            There is also a READ command which will read the       **
**            specified dataset into the `line.n` variables, You     **
**            could use this command, for example, to check that the **
**            contents of a SYS1.PARMLIB member is as expected.      **
**                                                                   **
**            The SELECT command can be used to read a job's sysout  **
**            into the `line.n` variables. You can then check the    **
**            contents of the output from a job.                     **
**                                                                   **
**            The XF and XD commands can be used to save a job's     **
**            sysout into either a pre-allocated DD (e.g. a Unix     **
**            file) or a dataset.                                    **
**                                                                   **
** SYNTAX   - PIV                                                    **
**                                                                   **
** OUTPUT   - All output is written to DD SYSTSOUT.                  **
**                                                                   **
** INPUT    -                                                        **
**<           All commands and tests are read from DD INPUT.         **
**                                                                   **
**            The syntax rules for the input file are:               **
**                                                                   **
**            0. CONTINUATIONS                                       **
**                                                                   **
**               A line continuation is indicated by a comma `,` as  **
**               the last non-blank character (i.e. the same as a    **
**               REXX continuation).                                 **
**                                                                   **
**            1. COMMENTS                                            **
**                                                                   **
**               Lines with a blank in column 1 are treated as       **
**               comments and are simply printed as-is.              **
**                                                                   **
**            2. COMMANDS                                            **
**                                                                   **
**               A line NOT beginning with a blank is a command to   **
**               be processed. All commands are case-insensitive.    **
**               The output from each command is returned in REXX    **
**               variables called `line.n` where n = 1 to the number **
**               of lines of available output. The REXX variable     **
**               `line.0` contains the number of lines available.    **
**                                                                   **
**               A command may be either:                            **
**                                                                   **
**               - HELP                                              **
**                                                                   **
**                 Prints this help information.                     **
**                                                                   **
**               - A z/OS command (prefixed with a `/` character):   **
**                                                                   **
**                 /zoscommand                                       **
**                                                                   **
**               - REPLY msgno replytext                             **
**                                                                   **
**                 If `*nn msgno ...` is found in the command output **
**                 then reply by issuing:                            **
**                                                                   **
**                 /R nn,replytext                                   **
**                                                                   **
**               - PREFIX jobname                                    **
**                                                                   **
**                 Filter SPOOL files by job name                    **
**                                                                   **
**               - OWNER userid                                      **
**                                                                   **
**                 Filter SPOOL files by owner name                  **
**                                                                   **
**               - SYSNAME sysname                                   **
**                                                                   **
**                 Filter SPOOL files by system name                 **
**                                                                   **
**               - DEST destname                                     **
**                                                                   **
**                 Filter SPOOL files by destination name            **
**                                                                   **
**               - SORT columnnames                                  **
**                                                                   **
**                 Sets the SDSF column sort order                   **
**                                                                   **
**               - An SDSF primary command:                          **
**                                                                   **
**                 DA, O, H, I, ST, PS, etc                          **
**                 The PREFIX, OWNER, SYSNAME and DEST filters will  **
**                 influence the command response.                   **
**                                                                   **
**               - ?                                                 **
**                                                                   **
**                 Lists a jobs spool datasets (when issued after    **
**                 DA, O, H, I or ST primary command)                **
**                                                                   **
**               - SELECT jobname [sysoutdd [step [procstep]]]       **
**                                                                   **
**                 A special command to read the sysout of the       **
**                 specified jobname into the `line.n` variables.    **
**                                                                   **
**                 You can refine the sysout to be selected by       **
**                 sysoutdd, step name, and proc step name.          **
**                                                                   **
**               - USS command                                       **
**                                                                   **
**                 A special command to issue a Unix System Services **
**                 shell command to put output in `line.n` variables.**
**                                                                   **
**               - READ {dsn | ddname | pathname}                    **
**                                                                   **
**                 A special command to read the contents of the     **
**                 specified dataset into the `line.n` variables.    **
**                                                                   **
**                 If `dsn` contains a `.` then it is treated as a   **
**                 fully qualified dataset name that will be         **
**                 dynamically allocated, otherwise it is assumed to **
**                 be the name of a pre-allocated DD in your JCL.    **
**                                                                   **
**                 If `dsn` contains a `/` then it is treated as a   **
**                 Unix path name. The content of the file will be   **
**                 converted to EBCDIC (IBM-1047) if necessary.      **
**                                                                   **
**               - SET var = value                                   **
**                                                                   **
**                 Sets an SDSF/REXX interface special variable.     **
**                                                                   **
**                 The list of valid variables is described in       **
**                 "SDSF Operation and Customization" (SA23-2274)    **
**                 in Table 180 "Special REXX Variables".            **
**                                                                   **
**                 Some useful ones (when using XD/XDC/XF/XFC) are:  **
**                                                                   **
**                 ISFPRTDDNAME    Export DD name (for XF/XFC)       **
**                 ISFPRTDSNAME    Export data set name (for XD/XDC) **
**                 ISFPRTDISP      Disposition (NEW/OLD/SHR/MOD)     **
**                 ISFPRTBLKSIZE   Default 3120 (27994 is better)    **
**                 ISFPRTLRECL     Default 240                       **
**                 ISFPRTRECFM     Default VBA                       **
**                 ISFPRTSPACETYPE Default BLKS                      **
**                 ISFPRTPRIMARY   Default 500                       **
**                 ISFPRTSECONDARY Default 500                       **
**                                                                   **
**               - XD    jobname [sysoutdd [step [procstep]]         **
**                 XDC   jobname [sysoutdd [step [procstep]]         **
**                                                                   **
**                 Export the sysout of the specified jobname to     **
**                 the dataset specified in REXX special variable    **
**                 ISFPRTDSNAME (see SET above).                     **
**                                                                   **
**                 You can refine the sysout to be selected by       **
**                 sysoutdd, step name, and proc step name.          **
**                                                                   **
**               - XF    jobname [sysoutdd [step [procstep]]         **
**                 XFC   jobname [sysoutdd [step [procstep]]         **
**                                                                   **
**                 Export the sysout of the specified jobname to     **
**                 the pre-allocated DD specified in REXX special    **
**                 variable ISFPRTDDNAME (see SET above).            **
**                                                                   **
**                 You can refine the sysout to be selected by       **
**                 sysoutdd, step name, and proc step name.          **
**                                                                   **
**               - SHOW ?                                            **
**                 Lists the possible column names for the           **
**                 SDSF command last issued (e.g. DA, O, etc)        **
**                                                                   **
**               - SHOW column [column...]                           **
**                 Displays specific columns (for example, JNAME,    **
**                 JOBID, PNAME). Use `SHOW ?` to list all the       **
**                 valid column names that you can specify for a     **
**                 particular ISPF panel (DA, O, ST, etc).           **
**                                                                   **
**               - SHOW ON                                           **
**                 Automatically prints command output from now on.  **
**                                                                   **
**               - SHOW OFF                                          **
**                 Suppresses printint command output from now on.   **
**                                                                   **
**               - SHOW                                              **
**                 Displays the default columns (appropriate for     **
**                 the command last issued) or the current           **
**                 contents of the `line.n` variables (if the        **
**                 command last issued was READ).                    **
**                                                                   **
**               - SHOW nnn                                          **
**                 Limits the acquired output to nnn lines maximum.  **
**                                                                   **
**               - SHOW heading[,m[,n]]                              **
**                 Prints the heading text followed by lines with    **
**                 line numbers between `m` and `n`. The             **
**                 default is to print ALL lines. A negative number  **
**                 is relative to the last line, so for example:     **
**                                                                   **
**                   SHOW last lines,-5                              **
**                                                                   **
**                 ...will print the heading `LAST LINES` followed   **
**                 by the last 5 lines of output.                    **
**                                                                   **
**               - SHOW 'word [word...]'                             **
**                 Prints each output line that contains at least    **
**                 one of the specified words.                       **
**                                                                   **
**           3. TESTS                                                **
**                                                                   **
**              There are several alternative test syntaxes that     **
**              you can use. Mostly, you would only use the ASSERT   **
**              syntax:                                              **
**                                                                   **
**              a. ASSERT syntax:                                    **
**                                                                   **
**                 ASSERT expression                                 **
**                                                                   **
**                 The expression is evaluated and if true then the  **
**                 return code is set to 0 (pass), else the return   **
**                 code is set to 4 (fail).                          **
**                                                                   **
**                 The test expression can be any expression that is **
**                 valid on a REXX `if` statement. For example,      **
**                                                                   **
**                 ASSERT isPresent('SOMETHING')                     **
**                   or                                              **
**                 ASSERT find('SOMETHING')                          **
**                                                                   **
**                 ...means:                                         **
**                                                                   **
**                 "Set return code 0 if the string 'SOMETHING' is   **
**                  present in the output, else set return code 4"   **
**                                                                   **
**              b. IF syntax:                                        **
**                                                                   **
**                 IF expression THEN rc = x [; ELSE ...]            **
**                                                                   **
**                 This is exactly the same syntax as the REXX `if`  **
**                 statement. The ASSERT example above could be      **
**                 equivalently written as:                          **
**                 if \isPresent('SOMETHING') then rc = 8            **
**                 ...which means                                    **
**                 "If the string 'SOMETHING' is not (\) present in  **
**                 the output then set return code 8, else set return**
**                 code 0"                                           **
**                                                                   **
**              c. A combination of USING, and PASSIF or FAILIF:     **
**                                                                   **
**                 USING template                                    **
**                 PASSIF expression                                 **
**                 FAILIF expression                                 **
**                                                                   **
**                 This is useful if you want to check a value that  **
**                 may vary from time to time (i.e. is not simply a  **
**                 constant string) and therefore needs to be        **
**                 extracted from the output and assigned to a REXX  **
**                 variable in order to test it.                     **
**                                                                   **
**                 USING  sets the parsing template to be applied    **
**                        to each line of the output. The template   **
**                        can be anything that is valid on a REXX    **
**                        `parse var line.n` statement, where n = 1  **
**                        to the number of lines of output that are  **
**                        available to be parsed.                    **
**                                                                   **
**                 PASSIF sets the return code to 0 if the REXX      **
**                        expression on PASSIF is true, or 4 if the  **
**                        expression is false.                       **
**                                                                   **
**                 FAILIF sets the return code to 4 if the REXX      **
**                        expression on FAILIF is true, or 0 if the  **
**                        expression is false.                       **
**                                                                   **
**                 For example, you may want to verify that spool    **
**                 usage is acceptable by checking the output of a   **
**                 `$DSPOOL` JES command, which may look like:       **
**                                                                   **
**                 $HASP893 VOLUME(SPOOL1)  STATUS=ACTIVE,PERCENT=23 **
**                 $HASP646 23.6525 PERCENT SPOOL UTILIZATION        **
**                                                                   **
**                 To verify this, you could use:                    **
**                                                                   **
**                 USING msgno percent .                             **
**                 PASSIF msgno = '$HASP646' & percent < 80          **
**                                                                   **
**                 This will cause each line of the output to be     **
**                 parsed and the first and second words of each     **
**                 line to be assigned to the REXX variables 'msgno' **
**                 and 'percent' respectively. If a line is found    **
**                 where 'msgno' is '$HASP646' and the 'percent'     **
**                 value is less than 80, then return code 0 is set. **
**                 If no line containing $HASP646 is found, or the   **
**                 percent value is more than 80, then return code   **
**                 4 is set. The processing of output lines stops    **
**                 when the expression on PASSIF or FAILIF is true.  **
**                 Alternatively, you could examine the $HASP893     **
**                 messages:                                         **
**                                                                   **
**                 USING msgno . 'PERCENT='percent .                 **
**                 PASSIF msgno = '$HASP893' & percent < 80          **
**                                                                   **
**                 This will cause each line of the output to be     **
**                 parsed and the message number and percent         **
**                 value to be extracted. Processing is similar to   **
**                 the previous example.                             **
**                                                                   **
**              The job step return code is set to the highest       **
**              return code (rc) set by any test.                    **
**                                                                   **
**              There are a few convenience functions in the PIV     **
**              REXX procedure that you can on the ASSERT, IF,       **
**              PASSIF and FAILIF commands if you want.              **
**                                                                   **
**              You can of course use any of the REXX built-in       **
**              functions too. For example:                          **
**                                                                   **
**              subword(line.3,2) = 'HI'                             **
**                                                                   **
**              Function                Returns 1 (true) when        **
**              ----------------------- ---------------------------- **
**              find(str)               str is found in any line     **
**              find(str[,str...])      ALL strings are on one line  **
**              isPresent(str)          str is found in any line     **
**              isPresent(str,line.n)   str is found in line.n       **
**              isAbsent(str)           str is not found in any line **
**              isAbsent(str,line.n)    str is not found in line.n   **
**              isNum(str)              str is an integer            **
**              isWhole(str)            str is an integer            **
**              isHex(str)              str is non-blank hexadecimal **
**              isAlpha(str)            str is alphanumeric          **
**              isUpper(str)            str is upper case alphabetic **
**              isLower(str)            str is lower case alphabetic **
**              isMixed(str)            str is mixed case alphabetic **
**                                                                   **
**>                                                                  **
** EXAMPLE  - //PIV      EXEC PGM=IKJEFT1A,PARM='%PIV'               **
**            //SYSEXEC  DD DISP=SHR,DSN=your.rexx.lib               **
**            //SYSTSIN  DD DUMMY                                    **
**            //SYSTSPRT DD SYSOUT=*                                 **
**            //INPUT    DD DATA,DLM='++'                            **
**              This tests the D ETR command output                  **
**            /D ETR                                                 **
**            show                                                   **
**              Mode must be STP:                                    **
**            assert word(line.4,4) = 'STP'                          **
**              Stratum must be less than 3:                         **
**            assert word(line.5,6) < 3                              **
**            ++                                                     **
**                                                                   **
**            The output from the D ETR command is captured in line.n**
**            variables like this:                                   **
**            line.0 = 9 (i.e. the number of returned lines)         **
**            line.1 = ISF031 CONSOLE xxxxxxxx ACTIVATED             **
**            line.2 = D ETR                                         **
**            line.3 = IEA386I hh.mm.ss TIMING STATUS nnn            **
**            line.4 = SYNCHRONIZATION MODE = STP                    **
**            line.5 =   THIS SERVER IS A STRATUM 2                  **
**            line.6 =   CTN ID = yyyyyyyy                           **
**            line.7 =   THE STRATUM 1 NODE ID = nnnnn.M...          **
**            line.8 =   THIS IS THE BACKUP TIME SERVER              **
**            line.9 =   NUMBER OF USABLE TIMING LINKS = nn          **
**                                                                   **
**            The above will exit with return code 4 if word 4 of    **
**            command output line 4 is not 'STP', and will exit with **
**            return code 4 if the stratum level is not 1 or 2.      **
**                                                                   **
**            Alternatively, you could use:                          **
**                                                                   **
**            /D ETR                                                 **
**            using keyword . . mode .                               **
**            passif keyword = 'SYNCHRONIZATION' & mode = 'STP'      **
**            using . . . . keyword level .                          **
**            passif keyword = 'STRATUM' & level < 3                 **
**                                                                   **
**            Return code 4 means FAIL, and 0 means PASS.            **
**                                                                   **
**                                                                   **
**********************************************************************/

trace o
  g. = ''
  head. = ''
  call Prolog
  isfdelay = 5            /* Console command reply delay in seconds */
  isfprtblksize = 27994   /* Block size for XD, XDC, XF and XFC     */

  line.0 = 0              /* Number of command response lines       */
  g.0TABULAR = 0          /* Indicate it is not SDSF tabular output */
  g.0SEPARATOR = 1        /* A separator line is wanted             */
  rc = isfcalls('ON')
  nMaxRC = 0
  sLine = getLine()
  g.0COMMENT.0 = 0
  do while g.0RC = 0
    parse upper var sLine c +1 0 sVerb sOp1 sOp2 . 0 . sOperands
    select
      /*
       *------------------------------------------------------------
       * Comment text
       *------------------------------------------------------------
       */
      when c = ' ' then do /* This is a comment */
        /* Comments are accumulated and emitted (after a separator)
           before the next command */
        n = g.0COMMENT.0 + 1
        g.0COMMENT.0 = n
        g.0COMMENT.n = sLine
      end
      /*
       *------------------------------------------------------------
       * /sdsfcommand
       *------------------------------------------------------------
       */
      when c = '/' then do /* Issue a (slash) console command */
        call emitSeparatorCommentsAndCommand sLine
        g.0SEPARATOR = 1
        cmd.0 = 1
        cmd.1 = substr(sLine,2)
        address SDSF 'ISFSLASH (cmd.) (WAIT'
        drop line.
        line.0 = isfulog.0
        do i = 1 to isfulog.0
          line.i = isfulog.i
        end
        g.0TABULAR = 0 /* Not SDSF tabular output */
        if g.0AUTOSHOW
        then call emitLines
      end
      /*
       *------------------------------------------------------------
       * SET variable '=' value
       *------------------------------------------------------------
       */
      when sVerb = 'SET' then do 
        /* Set a REXX variable (usually an SDSF REXX interface var */
        call emitSeparatorCommentsAndCommand sVerb sOperands
        interpret sOperands /* For example: ISFPRTDDNAME = 'LOG' */
      end
      /*
       *------------------------------------------------------------
       * IF expression THEN rc = n [; ELSE rc = m]
       *------------------------------------------------------------
       */
      when sVerb = 'IF' then do
        /* Check the previous command output and set return code */
        call emitComments
        sUpperLine = translate(sLine)
        nThen = pos(' THEN',sUpperLine) /* ...not bullet proof */
        sIf = left(sLine,nThen)     /* Extract the 'if' clause */
        parse var sIf . sExpression /* Extract the 'if' expression */
        interpret 'bExpression =' sExpression
        rc = 0
        say       sLine
        interpret sLine
        if bExpression = 1
        then sResult = '(true:  rc='rc')'
        else sResult = '(false: rc='rc')'
        if rc = 0
        then say 'Pass:  ' left(sLine,80) sResult
        else say 'Failed:' left(sLine,80) sResult
        nMaxRC = max(nMaxRC,rc)
      end
      /*
       *------------------------------------------------------------
       * ASSERT expression
       *------------------------------------------------------------
       */
      when sVerb = 'ASSERT' then do
        call emitComments
        parse var sLine . sExpression
        interpret 'bExpression =' sExpression
        if bExpression = 1
        then do
          say 'Pass:  ' left(sLine,80) '(true:  rc=0)'
          rc = 0
        end
        else do
          say 'Failed:' left(sLine,80) '(false: rc=4)'
          rc = 4
        end
        nMaxRC = max(nMaxRC,rc)
      end
      /*
       *------------------------------------------------------------
       * USING template
       *------------------------------------------------------------
       */
      when sVerb = 'USING' then do
        call emitCommentsAndCommand sVerb sOperands
        parse var sLine . g.0USING
      end
      /*
       *------------------------------------------------------------
       * PASSIF expression
       *------------------------------------------------------------
       */
      when sVerb = 'PASSIF' then do
        /* Set return code 0 if the expression is true */
        call emitComments
        parse var sLine . sExpression
        bExpression = 0
        do i = 1 to line.0 until bExpression
          interpret 'parse var line.'i g.0USING
          interpret 'bExpression =' sExpression
          bExpression = bExpression = 1
        end
        if bExpression = 1
        then do
          say 'Pass:  ' left(sLine,80) '(true:  rc=0) on line' i
          rc = 0
        end
        else do
          say 'Failed:' left(sLine,80) '(false: rc=4)'
          rc = 4
        end
        nMaxRC = max(nMaxRC,rc)
      end
      /*
       *------------------------------------------------------------
       * FAILIF expression
       *------------------------------------------------------------
       */
      when sVerb = 'FAILIF' then do
        /* Set return code 4 if the expression is true */
        call emitComments
        parse var sLine . sExpression
        bExpression = 0
        do i = 1 to line.0 until bExpression
          interpret 'parse var line.'i g.0USING
          interpret 'bExpression =' sExpression
          bExpression = bExpression = 1
        end
        if bExpression = 1
        then do
          say 'Failed:' left(sLine,80) '(true:  rc=4) on line' i
          rc = 4
        end
        else do
          say 'Pass:  ' left(sLine,80) '(false: rc=0)'
          rc = 0
        end
        nMaxRC = max(nMaxRC,rc)
      end
      /*
       *------------------------------------------------------------
       * REPLY msgno replytext
       *------------------------------------------------------------
       */
      when sVerb = 'REPLY' then do
        /* Reply to a specified message number */
        call emitComments
        call emitCommand sVerb sOperands
        parse var sOperands sMsgNo sReply
        if sMsgNo <> ''
        then do
          bReplied = 0
          do i = 1 to line.0 until bReplied
            parse var line.i . . . sWTOR
            sWTOR = strip(sWTOR)
            if left(sWTOR,1) = '*'
            then do
              parse var sWTOR '*'nReply sMsgNoPrompt .
              if datatype(nReply,'WHOLE') & sMsgNo = sMsgNoPrompt
              then do
                cmd.0 = 1
                cmd.1 = 'R' nReply','strip(sReply)
                address SDSF 'ISFSLASH (cmd.) (WAIT'
                bReplied = 1
              end
            end
          end
          if bReplied
          then do
            drop line.
            line.0 = isfulog.0
            do i = 1 to isfulog.0
              line.i = isfulog.i
            end
            g.0TABULAR = 0
            if g.0AUTOSHOW
            then call emitLines
          end
        end
      end
      /*
       *------------------------------------------------------------
       * PREFIX jobname
       *------------------------------------------------------------
       */
      when abbrev('PREFIX',sVerb,3) then do /* Filter on jobname */
        call emitSeparatorCommentsAndCommand sVerb sOperands
        isfprefix = sOperands
      end
      /*
       *------------------------------------------------------------
       * OWNER ownername
       *------------------------------------------------------------
       */
      when abbrev('OWNER',sVerb,3) then do /* Filter on owner */
        call emitSeparatorCommentsAndCommand sVerb sOperands
        isfowner = sOperands
      end
      /*
       *------------------------------------------------------------
       * SYSNAME systemname
       *------------------------------------------------------------
       */
      when abbrev('SYSNAME',sVerb,3) then do /* Filter on sysname */
        call emitSeparatorCommentsAndCommand sVerb sOperands
        isfsysname = sOperands
      end
      /*
       *------------------------------------------------------------
       * DEST destinationname
       *------------------------------------------------------------
       */
      when abbrev('DEST',sVerb,3) then do /* Filter on destination */
        call emitSeparatorCommentsAndCommand sVerb sOperands
        isfdest = sOperands
      end
      /*
       *------------------------------------------------------------
       * SORT columnnames
       *------------------------------------------------------------
       */
      when sVerb = 'SORT' then do /* Set column sort order */
        call emitCommentsAndCommand sVerb sOperands
        isfsort = sOperands
      end
      /*
       *------------------------------------------------------------
       * SHOW {ON | OFF | limit | ? | 'word...' | heading[,n[,m]] }
       *------------------------------------------------------------
       */
      when abbrev('SHOW',sVerb,2) then do
        call emitComments
        call emitCommand sVerb sOperands
        select
          when sOp1 = 'ON'  then g.0AUTOSHOW = 1 /* Print output */
          when sOp1 = 'OFF' then g.0AUTOSHOW = 0 /* Suppress output */
          when datatype(sOp1,'WHOLE') then do /* Limit acquired lines*/
            if sOp1 > 0
            then g.0MAXLINES = sOp1
            say '     PIV001I Acquire limit is now' g.0MAXLINES 'lines'
          end
          when g.0TABULAR then do /* Last was SDSF primary command */
            if sOp1 = '?'  /* Print gamut of column names? */
            then do
              /* Display the valid column names for this SDSF panel */
              say 'Valid column names for' g.0CMD 'are:'
              say '    ' 'Name        ' 'Title      '
              say '    ' '------------' '-----------'
              do j = 1 to g.0COLTITLE.0
                sColName  = g.0COLTITLE.j
                sColTitle = g.0COLTITLE.sColName
                say '    ' left(sColName,12) sColTitle
              end
            end
            else call emitColumns sOperands
          end
          when left(sOp1,1) = "'" then do
            /* Print only lines containing any of these words */
            call emitHits sLine
          end
          otherwise do
            /* Print (possibly a subset of) the output lines */
            parse var sOperands sHeading','nFrom','nTo
            call emitLines sHeading,nFrom,nTo
          end
        end
      end
      /*
       *------------------------------------------------------------
       * READ
       *------------------------------------------------------------
       */
      when sVerb = 'READ' then do /* Read dataset into stem `line.` */
        parse var sLine . sOperands
        call emitSeparatorCommentsAndCommand sVerb sOperands
        g.0SEPARATOR = 1
        sOperands = strip(sOperands)
        select
          when pos('/',sOperands) > 0 then do /* Read Unix file */
            nLines = readUnixFile(sOperands)
          end
          when pos('.',sOperands) = 0 then do /* Read z/OS DD(s) */
            do i = 1 to words(sOperands) while g.0RC = 0
              sDDNAME = word(sOperands,i)
              'EXECIO' g.0MAXLINES 'DISKR' sDDNAME '(FINIS STEM line.'
              g.0RC = rc
            end
          end
          otherwise do /* Read z/OS dataset */
            nLines = readDataset(sOperands)
          end
        end
        g.0TABULAR = 0 /* Indicate it is not SDSF tabular output */
        if g.0AUTOSHOW
        then call emitLines
      end
      /*
       *------------------------------------------------------------
       * USS unixcommand
       *------------------------------------------------------------
       */
      when sVerb = 'USS' then do /* Issue Unix command */
        parse var sLine . sOperands
        call emitSeparatorCommentsAndCommand sVerb sOperands
        g.0SEPARATOR = 1
        nLines = issueUnixCommand(sOperands)
        g.0TABULAR = 0 /* Indicate it is not SDSF tabular output */
        if g.0AUTOSHOW
        then call emitLines
      end
      /*
       *------------------------------------------------------------
       * ?   (list a job's sysout datasets)
       *------------------------------------------------------------
       */
      when sVerb = '?' then do
        call emitSeparatorCommentsAndCommand sVerb sOperands
        if wordpos(g.0CMD,'DA I H O ST') = 0
        then do
          say '     PIV003E Issue DA, I, H, O or ST before issuing "'sVerb'"'
        end
        else do
          g.0TABULAR = 0 /* Indicate not SDSF tabular output */
          /* List this job's sysout datasets using the `?` command */
          address SDSF 'ISFACT' g.0CMD "TOKEN('"sToken"') PARM(NP ?)",
                                       "PREFIX so_"
          drop line.
          line.0 = 0
          do r = 1 to g.0ROWS
            say '    ' so_JNAME.r so_JOBID.r so_DDNAME.r
          end
        end
      end
      /*
       *------------------------------------------------------------
       * SELECT jobname [sysoutdd [stepname [procstep]]]
       *------------------------------------------------------------
       */
      when abbrev('SELECT',sVerb,1) then do
        /* Read job output and store it in line.n variables */
        g.0SEPARATOR = 1
        call emitSeparatorCommentsAndCommand sVerb sOperands
        if wordpos(g.0CMD,'DA I H O ST') = 0
        then do
          say '     PIV003E Issue DA, I, H, O or ST before issuing "'sVerb'"'
        end
        else do
          g.0TABULAR = 0 /* Indicate it is not SDSF tabular output */
          drop head.
          head. = ''
          parse var sOperands sJobName sSysoutDD sStepName sProcStep
          if sJobName = '' then sJobName = JNAME.1
          drop line.
          line.0 = 0
          do r = 1 to g.0ROWS
            if JNAME.r = sJobName
            then do
              call readJobOutput TOKEN.r,JNAME.r,JOBID.r,,
                                 sSysoutDD,sStepName,sProcStep
            end
          end
        end
      end
      /*
       *------------------------------------------------------------
       * XF  jobname [sysoutdd [stepname [procstep]]]
       * XFC jobname [sysoutdd [stepname [procstep]]]
       * XD  jobname [sysoutdd [stepname [procstep]]]
       * XDC jobname [sysoutdd [stepname [procstep]]]
       *------------------------------------------------------------
       */
      when wordpos(sVerb,'XF XFC XD XDC') > 0 then do
        /* XF  will export the job output to a pre-allocated DD name */
        /* XFC same as XF but will Close the output DD afterwards */
        /* XD  will export the job output to a dataset */
        /* XDC same as XD but will Close the output dataset afterwards */
        call emitCommentsAndCommand sVerb sOperands
        g.0SEPARATOR = 1
        if wordpos(g.0CMD,'DA I H O ST') = 0
        then do
          say '     PIV003E Issue DA, I, H, O or ST before issuing "'sVerb'"'
        end
        else do
          g.0TABULAR = 0 /* Indicate it is not SDSF tabular output */
          parse var sOperands sJobName sSysoutDD sStepName sProcStep
          drop line.
          line.0 = 0
          if sJobName = '' /* If no filter, export all job output */
          then do
            do r = 1 to g.0ROWS
              say '     PIV002I Exporting all sysout for job' JNAME.r
              call exportAllOutput TOKEN.r
            end
          end
          else do /* Export sysout datasets matching the filter */
            do r = 1 to g.0ROWS
              if JNAME.r = sJobName
              then do
                say '     PIV002I Exporting filtered sysout for job',
                                  JNAME.r
                call exportJobOutput TOKEN.r,JNAME.r,JOBID.r,,
                                     sSysoutDD,sStepName,sProcStep
              end
            end
          end
        end
      end
      /*
       *------------------------------------------------------------
       * HELP
       *------------------------------------------------------------
       */
      when sVerb = 'HELP' then do
        call emitSeparatorCommentsAndCommand sVerb sOperands
        g.0SEPARATOR = 1
        do i = 1 until left(sourceline(i),3) = '**<'
        end
        do i = i until sEOD = '**>'
          parse value sourceline(i) with 1 sEOD +3 15 sHelp 69 .
          say '    ' sHelp
        end
      end
      /*
       *------------------------------------------------------------
       * Issue an SDSF primary command (DA, H, I, etc)
       *------------------------------------------------------------
       */
      otherwise do
        call emitSeparatorCommentsAndCommand sVerb sOperands
        g.0SEPARATOR = 1
        isfcols = ''
        g.0CMD = sVerb /* Remember SDSF primary command for later */
        address SDSF "ISFEXEC '"sLine"'(DELAYED"
        if rc <> 0
        then do /* Display error messages if the command failed */
          nMaxRC = max(nMaxRC,rc)
          do i = 1 to isfmsg2.0
            say isfmsg2.i
          end
        end
        else do /* Display title line */
          g.0TABULAR = 1 /* Indicate SDSF tabular output */
          isfsort = '' /* Reset column sort */
          g.0ISFTLINE   = isftline
          g.0ISFDISPLAY = isfdisplay
          g.0ISFTITLES  = isftitles
          /* Save column names and titles for later */
          nColumns = words(isfcols)
          /* Hack due to '  ID' being present... */
          if word(isftitles,1) = "'"
          then isftitles = subword(isftitles,2)
          drop width.
          width. = 0
          rj. = 1
          width.0 = nColumns
          g.0COLTITLE.0 = nColumns
          do c = 1 to g.0COLTITLE.0
            sColName = word(isfcols,c)
            sColTitle = strip(word(isftitles,c),'BOTH',"'")
            g.0COLTITLE.sColName = sColTitle
            g.0COLTITLE.c = sColName
            width.sColName = length(sColTitle)
          end
          /* Save command output, if any, in `line.` stem variables */
          drop line.
          drop colname.
          g.0ROWS = isfrows
          line.0 = isfrows
          colname.0 = nColumns
          do r = 1 to line.0
            line.r = ''
            do c = 1 to nColumns
              sColName = word(isfcols,c)
              colname.c = sColName
              sColValue = value(sColName'.'r)
              if sColValue = '' then sColValue = '.'
              line.r = line.r sColValue
              width.sColName = max(width.sColName,length(sColValue))
              rj.sColName = rj.sColName & datatype(sColValue,'NUM')
            end
            line.r = substr(line.r,2)
          end
          if g.0AUTOSHOW
          then call emitColumns
        end
      end
    end
    sLine = getLine()
  end

  call Epilog

exit nMaxRC

Epilog:
  rc = isfcalls('OFF')

  say
  say copies('-',130)
  say
  if nMaxRC = 0
  then say 'Result: PIV successful'
  else say 'Result: PIV failed with maxrc='nMaxRC
  say
return

readJobOutput:
  parse arg sToken,sJob,sJobId,sSysoutDD,sStepName,sProcStep
  /* List this job's sysout datasets using the `?` SDSF line command */
  address SDSF 'ISFACT' g.0CMD "TOKEN('"sToken"') PARM(NP ?)",
                               "(PREFIX so_"
  line.0 = 0
  nMaxLines = g.0MAXLINES
  /* Read one or more sysout datasets into `line.n` variables */
  do j = 1 to so_ddname.0 while line.0 < g.0MAXLINES
    if isMatch(sSysoutDD,so_ddname.j),
     & isMatch(sStepName,so_stepn.j),
     & isMatch(sProcStep,so_procs.j)
    then do
      /* Allocate the specified sysout dataset using the SA command */
      address SDSF 'ISFACT' g.0CMD "TOKEN('"so_token.j"') PARM(NP SA)"
      /* Append a header that identifies the output being acquired  */
      n = line.0 + 1
      head.n = 'JOB='left(sJob,8),
             'JOBID='left(sJobId,8),
                'DD='left(so_ddname.j,8),
          'PROCSTEP='left(so_procs.j,8),
              'DSID='left(so_dsid,j,8)
      /* Read the sysout dataset contents (until limit reached) */
      'EXECIO' nMaxLines 'DISKR' isfddname.1 '(FINIS STEM read.'
      nMaxLines = nMaxLines - read.0
      /* Append the acquired output to the `line.n` variables */
      do k = 1 to read.0
        call appendLine read.k
      end
    end
  end
  /* If user specified SHOW ON, then automatically display the lines */
  if g.0AUTOSHOW
  then call emitLines
return

exportAllOutput:
  parse arg sToken
  /* Export all of this job's sysout datasets */
  address SDSF 'ISFACT' g.0CMD "TOKEN('"sToken"') PARM(NP" sVerb")"
  isfprtdisp = 'MOD' /* Append subsequent sysout datasets */
  /* If user specified SHOW ON, then automatically display the lines */
  if g.0AUTOSHOW
  then call emitLines
return

exportJobOutput:
  parse arg sToken,sJob,sJobId,sSysoutDD,sStepName,sProcStep
  /* List this job's sysout datasets using the `?` SDSF line command */
  address SDSF 'ISFACT' g.0CMD "TOKEN('"sToken"') PARM(NP ?)",
                               "(PREFIX so_"
  line.0 = 0
  /* Read one or more sysout datasets into `line.n` variables */
  do j = 1 to so_ddname.0
    if isMatch(sSysoutDD,so_ddname.j),
     & isMatch(sStepName,so_stepn.j),
     & isMatch(sProcStep,so_procs.j)
    then do
      /* Export the specified sysout dataset using the Xxx SDSF */
      /* line command. The ISFPRTxxxxxx variables must be set first */
      address SDSF 'ISFACT' g.0CMD "TOKEN('"so_token.j"')",
                                   "PARM(NP" sVerb")"
      isfprtdisp = 'MOD' /* Append subsequent sysout datasets */
    end
  end
  /* If user specified SHOW ON, then automatically display the lines */
  if g.0AUTOSHOW
  then call emitLines
return

isMatch: procedure
  parse arg sPattern,sString
  if sPattern = '' then return 1       /* Null pattern matches all */
  if right(sPattern,1) = '*'                  /* Example: JES*     */
  then do
    sPattern = strip(sPattern,'TRAILING','*') /*          JES      */
    nPattern = length(sPattern)               /*          ---  (3) */
    if nPattern = 0
    then bMatch = 1                           /* '*' matches all   */
    else bMatch = left(sString,nPattern) = sPattern
  end
  else do
    bMatch = sString = sPattern
  end
return bMatch

appendLine: procedure expose line.
  parse arg sLine
  n = line.0 + 1
  line.n = sLine
  line.0 = n
return

readDataset: procedure expose g. line.
  parse upper arg sDSN
  sDSN = strip(sDSN,'BOTH',"'")
  sFileStatus = sysdsn("'"sDSN"'")
  if sFileStatus = 'OK'
  then do
    call quietly "ALLOCATE FILE(PIV) DSNAME('"sDSN"')",
                 'INPUT SHR REUSE'
    'EXECIO * DISKR PIV (FINIS STEM line.'
    call quietly 'FREE FILE(PIV)'
  end
  else do
    say '     PIV004W Could not read dataset:' sDSN '-' sFileStatus
  end
return line.0

readUnixFile: procedure expose g. line.
  parse arg sPath
  rc = syscalls('ON') /* Sets up predefined variables */
  address SYSCALL
  'open (sPath)' o_rdonly
  if rc = 0 & retval = 0
  then do
    fd = retval /* File descriptor */
    pccsid = '0000'x  /* Program Coded Character Set Id */
    fccsid = '0000x'  /* File Coded Character Set Id */
    /* Enable automatic character set conversion */
    'f_control_cvt (fd)' cvt_setcvton 'pccsid fccsid'
    len = g.0MAXLINES * 255
    'read (fd) data' len
    if rc = 0
    then do
      do i = 1 while length(data) > 0 & i <= g.0MAXLINES
        parse var data line '15'x data
        line.i = line
        line.0 = i
      end
    end
    else do
      say '     PIV005W Could not read file:' sPath 'errno='errno,
                       'errnojr='right(errnojr,8,0)
      line.0 = 0
    end
    'close (fd)'
  end
  else do
    say '     PIV006W Could not open file:' sPath 'errno='errno,
                     'errnojr='rigth(errnojr,8,0)
    line.0 = 0
  end
  address
  rc = syscalls('OFF')
return line.0

issueUnixCommand: procedure expose g. line.
  parse arg sCmd
  rc = syscalls('ON') /* Sets up predefined variables */
  address SYSCALL
  line.0 = 0
  rc = bpxwunix(sCmd,,line.,stderr.)
  if stderr.0 > 0
  then do /* Append stderr lines to the output as well */
    n = line.0
    do i = 1 to stderr.0
      n = n + 1
      line.n = '>' stderr.I
    end
    line.0 = n
  end
  address
  rc = syscalls('OFF')
return line.0

quietly: procedure expose g.
  parse arg sCommand
  rc = outtrap('o.')
  address TSO sCommand
  g.0RC = rc
  rc = outtrap('off')
return

emitSeparatorCommentsAndCommand: procedure expose g.
  parse arg sCommand
  call emitSeparator
  call emitComments
  call emitCommand sCommand
return

emitCommentsAndCommand: procedure expose g.
  parse arg sCommand
  call emitComments
  call emitCommand sCommand
return

emitSeparator: procedure expose g.
  if g.0SEPARATOR
  then do
    say
    say copies('-',120)
    g.0SEPARATOR = 0
  end
return

emitComments: procedure expose g.
  do i = 1 to g.0COMMENT.0
    say '    'g.0COMMENT.i
  end
  g.0COMMENT.0 = 0
return

emitCommand: procedure expose g.
  parse arg sCommand
  say
  say '===>' sCommand
  say
return

emitColumns:
  parse upper arg sColumns
  if sColumns = '' /* Show default columns for last command issued */
  then do
    sCmd = g.0CMD
    sColumns = g.0COLS.sCmd
    if sColumns = ''
    then sColumns = isfcols /* No default, so show all columns */
  end
  sHeadings = ''
  sRule     = ''
  nColumns = words(sColumns)
  do j = 1 to nColumns
    sColName = word(sColumns,j)
    if rj.sColName
    then sHeadings = sHeadings right(g.0COLTITLE.sColName,,
                                     width.sColName)
    else sHeadings = sHeadings  left(g.0COLTITLE.sColName,,
                                     width.sColName)
    sRule = sRule copies('-',width.sColName)
  end
  say '    ' g.0ISFTLINE g.0ISFDISPLAY
  say 'Line'sHeadings
  say '----'sRule
  /* Show each column vertically in a tablular format */
  do r = 1 to line.0
    row = ''
    do c = 1 to nColumns
      sColName = word(sColumns,c)
      sColValue = value(sColName'.'r)
      if rj.sColName
      then sColValue = right(sColValue,width.sColName)
      else sColValue =  left(sColValue,width.sColName)
      row = row sColValue
    end
    call emitLine r,substr(row,2)
  end
  say
return

emitHits: procedure expose lines.
  parse arg . sSearchWords
  sSearchWords = strip(sSearchWords,'BOTH',"'")
  nSearchWords = words(sSearchWords)
  do i = 1 to nSearchWords
    word.i = word(sSearchWords,i)
  end
  say
  say 'Line' sSearchWords
  say '----' copies('-',length(sSearchWords))
  do i = 1 to line.0
    do j = 1 to nSearchWords
      if pos(word.j,line.i) > 0
      then do
        call emitLine i,line.I
        leave
      end
    end
  end
return

emitLines: procedure expose line. g. head.
  parse arg sHeading,nFrom,nTo
  if \datatype(line.0,'WHOLE') then line.0 = 1
  if \datatype(nFrom, 'WHOLE') then nFrom  = 1
  if \datatype(nTo,   'WHOLE') then nTo    = line.0
  if nFrom < 0 then nFrom = nFrom + line.0 + 1 /* -n lines from end */
  if nTo   < 0 then nTo   = nTo   + line.0 + 1 /* -m lines from end */
  if nFrom < 1 then nFrom = 1
  if nTo <> 0
  then do
    if nTo > line.0 then nTo = line.0
    if nFrom > nTo
    then do
      nTemp = nTo
      nTo   = nFrom
      nFrom = nTemp
    end
  end
  if nTo-nFrom >= 0
  then do
    say
    if sHeading = '' & g.0TABULAR
    then do
      say '    ' g.0ISFTLINE '('g.0ISFDISPLAY')'
      say 'Line' g.0ISFTITLES
    end
    else do
      if head.1 = '' /* If no sysout dataset headings are present */
      then say 'Line' sHeading
    end
    do i = nFrom to nTo
      if head.i <> ''
      then do
        say
        say 'Line' head.i
        say '----' copies('-',length(head.i))
      end
      call emitLine i,line.i
    end
  end
  if line.0 = g.0MAXLINES
  then say '---- Output limit reached ('g.0MAXLINES 'lines)'
return

emitLine: procedure
  parse arg nLine,sLine
  parse var sLine sChunk +126 sRest
  say right(nLine,4,'0') sChunk
  do while sRest <> ''
    parse var sRest sChunk +126 sRest
    say '    ' sChunk
  end
return

getLine:
  'EXECIO 1 DISKR INPUT (STEM d.'
  g.0RC = rc
  sLine = strip(d.1,'TRAILING')
  do while g.0RC = 0 & right(sLine,1) = ',' /* Continuation */
    sLine = left(sLine,length(sLine)-1)
    'EXECIO 1 DISKR INPUT (STEM d.'
    g.0RC = rc
    if rc = 0
    then sLine = sLine || strip(d.1)
  end
return getSub(sLine)

getSub:
  /* Substitute all instances of <var> with the current */
  /* value of that REXX variable */
  parse arg sLine
  nLeft = pos('<',sLine)
  nRight = pos('>',sLine,nLeft+1)
  do while nLeft > 0 & nRight > 0
    parse var sLine sLeft'<'sVarName'>'sRight
    sVarName = only(sVarName,'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789')
    sLine = sLeft || value(sVarName) || sRight
    nLeft = pos('<',sLine)
    nRight = pos('>',sLine,nLeft+1)
  end
return sLine

/*
*------------------------------------------------------------
* Handy built-in functions
*------------------------------------------------------------
*/

only: procedure expose g.
  /* Remove all disallowed characters in the specified string */
  parse upper arg sText,sAllowed
  nFirstBad = verify(sText,sAllowed,'NOMATCH')
  do while nFirstBad > 0
    nNextGood = verify(sText,sAllowed,'MATCH',nFirstBad)
    if nNextGood > 0
    then sText = delstr(sText,nFirstBad,nNextGood-nFirstBad)
    else sText = delstr(sText,nFirstBad)
    nFirstBad = verify(sText,sAllowed,'NOMATCH')
  end
return sText

exists: procedure
  /* Determine whether the specified dataset or USS file exists */
  parse arg sDataset
  if pos('/',sDataset) > 0
  then do /* Check whether a Unix file exists */
    sPath = sDataset
    rc = syscalls('ON')
    address SYSCALL 'lstat (sPath) lstat.'
    bExists = retval = 0
    rc = syscalls('OFF')
  end
  else do /* Check whether a z/OS dataset exists */
    bExists = sysdsn("'"sDataset"'") = 'OK'
  end
return bExists

find: procedure expose line.
  /* args: word[,word...] */
  /* If ALL specified words are found on a single `line.` variable */
  /* then return 1, else return 0 */
  bPresent = 0
  do i = 1 to line.0 until bPresent
    bPresent = 1 /* Assume all tokens have been found on line.i */
    do j = 1 to arg() while bPresent
      bPresent = bPresent & pos(arg(j),line.i) > 0
    end
  end
  if bPresent
  then line.# = i /* Remember the line number satisfying the search */
  else line.# = 0 /* Indicate no line found with ALL words present */
return bPresent

isPresent: procedure expose line.
  parse arg sNeedle,sHaystack
  if sHaystack = ''
  then bPresent = find(sNeedle)
  else bPresent = pos(sNeedle,sHaystack) = 0
return bPresent

isDDName: procedure
  arg c +1 rest 0 string
  if length(string) > 8 | length(string) < 1 then return 0
  if pos(c,'ABCDEFGHIJKLMNOPQRSTUVWXYZ@#$') = 0 then return 0
return verify(rest,'ABCDEFGHIJKLMNOPQRSTUVWXYZ@#$0123456789') = 0

isAbsent: procedure expose line.
  parse arg sNeedle,sHaystack
return \isPresent(sNeedle,sHaystack)

isHex: procedure
  parse arg sString
  if sString = '' then return 0
return datatype(sString,'X')

isWhole: procedure
  parse arg sString
return datatype(sString,'WHOLE')

isNum: procedure
  parse arg sString
return datatype(sString,'WHOLE')

isAlpha: procedure
  parse arg sString
return datatype(sString,'ALPHANUMERIC')

isUpper: procedure
  parse arg sString
return datatype(sString,'UPPERCASE')

isLower: procedure
  parse arg sString
return datatype(sString,'LOWERCASE')

isMixed: procedure
  parse arg sString
return datatype(sString,'MIXEDCASE')

isOneOf: procedure
  parse arg sSet1,sSet2
  sSet = ''
  do i = 1 to words(sSet2)
    sWord = word(sSet2,i)
    if wordpos(sWord,sSet1) > 0
    then sSet = sSet sWord
  end
return sSet <> ''

Prolog:
  g.0MAXLINES  = 1000 /* Maximum command output or file input lines */
  g.0AUTOSHOW  = 1    /* Automatically show command output? */
  g.0ROWS      = 0
  g.0USING     = ''

  /* Set up the default columns to be displayed for each SDSF command */
  g.0COLS.DA   = 'JNAME   STEPN  PROCS    JOBID  OWNERID'
  g.0COLS.H    = 'JNAME   JOBID  OWNERID  PNAME  DATEE   TIMEE   RETCODE'
  g.0COLS.O    = 'JNAME   JOBID  OWNERID  PNAME  DATEE   TIMEE   RETCODE'
  g.0COLS.I    = 'JNAME   JOBID  OWNERID  PNAME  DATEE   TIMEE   STATUS'
  g.0COLS.ST   = 'JNAME   JOBID  OWNERID  PNAME  DATEE   TIMEE   RETCODE QUEUE'
  g.0COLS.PS   = 'JNAME   JOBID  STATUS   PPID   PID     COMMAND'
  g.0COLS.CK   = 'NAME    OWNER  STATE    STATUS RESULT'
  g.0COLS.INIT = 'INTNAME STATUS ICLASS'
  g.0COLS.PR   = 'DEVNAME STATUS SCLASS   MODE   FSSPROC FSSNAME'
  g.0COLS.LINE = 'DEVNAME STATUS NNODE'
  g.0COLS.NODE = 'NUMBER  STATUS NODENAME AUTH'

return
