# Third-party notices

The grammars archive of https://github.com/tkinnis/tree-sitter-grammars carries the tree-sitter runtime (v0.27.0), one library per grammar and the query files each language reads. This file reproduces, verbatim, the licence of every one of them.

In the archive, `libtree-sitter.dylib` is the runtime, `dylibs/<language>/` holds a grammar's library beside its query files, and `queries/<language>/` holds the query files of a language that has no library of its own. The query files are this repository's `queries/<language>/*.scm`.

## tree-sitter

`libtree-sitter.dylib` is compiled from https://github.com/tree-sitter/tree-sitter at v0.27.0 (6070dbfefd326bd735e5683eb128cc1b57dad0c0). `lib/src/unicode/LICENSE` covers the ICU headers under `lib/src/unicode/` that it compiles in.

### LICENSE

```text
The MIT License (MIT)

Copyright (c) 2018 Max Brunsfeld

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

### lib/src/unicode/LICENSE

```text
COPYRIGHT AND PERMISSION NOTICE (ICU 58 and later)

Copyright © 1991-2019 Unicode, Inc. All rights reserved.
Distributed under the Terms of Use in https://www.unicode.org/copyright.html.

Permission is hereby granted, free of charge, to any person obtaining
a copy of the Unicode data files and any associated documentation
(the "Data Files") or Unicode software and any associated documentation
(the "Software") to deal in the Data Files or Software
without restriction, including without limitation the rights to use,
copy, modify, merge, publish, distribute, and/or sell copies of
the Data Files or Software, and to permit persons to whom the Data Files
or Software are furnished to do so, provided that either
(a) this copyright and permission notice appear with all copies
of the Data Files or Software, or
(b) this copyright and permission notice appear in associated
Documentation.

THE DATA FILES AND SOFTWARE ARE PROVIDED "AS IS", WITHOUT WARRANTY OF
ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE
WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT OF THIRD PARTY RIGHTS.
IN NO EVENT SHALL THE COPYRIGHT HOLDER OR HOLDERS INCLUDED IN THIS
NOTICE BE LIABLE FOR ANY CLAIM, OR ANY SPECIAL INDIRECT OR CONSEQUENTIAL
DAMAGES, OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE,
DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER
TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
PERFORMANCE OF THE DATA FILES OR SOFTWARE.

Except as contained in this notice, the name of a copyright holder
shall not be used in advertising or otherwise to promote the sale,
use or other dealings in these Data Files or Software without prior
written authorization of the copyright holder.

---------------------

Third-Party Software Licenses

This section contains third-party software notices and/or additional
terms for licensed third-party software components included within ICU
libraries.

1. ICU License - ICU 1.8.1 to ICU 57.1

COPYRIGHT AND PERMISSION NOTICE

Copyright (c) 1995-2016 International Business Machines Corporation and others
All rights reserved.

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, and/or sell copies of the Software, and to permit persons
to whom the Software is furnished to do so, provided that the above
copyright notice(s) and this permission notice appear in all copies of
the Software and that both the above copyright notice(s) and this
permission notice appear in supporting documentation.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT
OF THIRD PARTY RIGHTS. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR
HOLDERS INCLUDED IN THIS NOTICE BE LIABLE FOR ANY CLAIM, OR ANY
SPECIAL INDIRECT OR CONSEQUENTIAL DAMAGES, OR ANY DAMAGES WHATSOEVER
RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF
CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN
CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

Except as contained in this notice, the name of a copyright holder
shall not be used in advertising or otherwise to promote the sale, use
or other dealings in this Software without prior written authorization
of the copyright holder.

All trademarks and registered trademarks mentioned herein are the
property of their respective owners.

2. Chinese/Japanese Word Break Dictionary Data (cjdict.txt)

 #     The Google Chrome software developed by Google is licensed under
 # the BSD license. Other software included in this distribution is
 # provided under other licenses, as set forth below.
 #
 #  The BSD License
 #  http://opensource.org/licenses/bsd-license.php
 #  Copyright (C) 2006-2008, Google Inc.
 #
 #  All rights reserved.
 #
 #  Redistribution and use in source and binary forms, with or without
 # modification, are permitted provided that the following conditions are met:
 #
 #  Redistributions of source code must retain the above copyright notice,
 # this list of conditions and the following disclaimer.
 #  Redistributions in binary form must reproduce the above
 # copyright notice, this list of conditions and the following
 # disclaimer in the documentation and/or other materials provided with
 # the distribution.
 #  Neither the name of  Google Inc. nor the names of its
 # contributors may be used to endorse or promote products derived from
 # this software without specific prior written permission.
 #
 #
 #  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND
 # CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES,
 # INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 # MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 # DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
 # LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 # CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 # SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR
 # BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 # LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
 # NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 # SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 #
 #
 #  The word list in cjdict.txt are generated by combining three word lists
 # listed below with further processing for compound word breaking. The
 # frequency is generated with an iterative training against Google web
 # corpora.
 #
 #  * Libtabe (Chinese)
 #    - https://sourceforge.net/project/?group_id=1519
 #    - Its license terms and conditions are shown below.
 #
 #  * IPADIC (Japanese)
 #    - http://chasen.aist-nara.ac.jp/chasen/distribution.html
 #    - Its license terms and conditions are shown below.
 #
 #  ---------COPYING.libtabe ---- BEGIN--------------------
 #
 #  /*
 #   * Copyright (c) 1999 TaBE Project.
 #   * Copyright (c) 1999 Pai-Hsiang Hsiao.
 #   * All rights reserved.
 #   *
 #   * Redistribution and use in source and binary forms, with or without
 #   * modification, are permitted provided that the following conditions
 #   * are met:
 #   *
 #   * . Redistributions of source code must retain the above copyright
 #   *   notice, this list of conditions and the following disclaimer.
 #   * . Redistributions in binary form must reproduce the above copyright
 #   *   notice, this list of conditions and the following disclaimer in
 #   *   the documentation and/or other materials provided with the
 #   *   distribution.
 #   * . Neither the name of the TaBE Project nor the names of its
 #   *   contributors may be used to endorse or promote products derived
 #   *   from this software without specific prior written permission.
 #   *
 #   * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 #   * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 #   * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
 #   * FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
 #   * REGENTS OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
 #   * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 #   * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 #   * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 #   * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
 #   * STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 #   * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
 #   * OF THE POSSIBILITY OF SUCH DAMAGE.
 #   */
 #
 #  /*
 #   * Copyright (c) 1999 Computer Systems and Communication Lab,
 #   *                    Institute of Information Science, Academia
 #       *                    Sinica. All rights reserved.
 #   *
 #   * Redistribution and use in source and binary forms, with or without
 #   * modification, are permitted provided that the following conditions
 #   * are met:
 #   *
 #   * . Redistributions of source code must retain the above copyright
 #   *   notice, this list of conditions and the following disclaimer.
 #   * . Redistributions in binary form must reproduce the above copyright
 #   *   notice, this list of conditions and the following disclaimer in
 #   *   the documentation and/or other materials provided with the
 #   *   distribution.
 #   * . Neither the name of the Computer Systems and Communication Lab
 #   *   nor the names of its contributors may be used to endorse or
 #   *   promote products derived from this software without specific
 #   *   prior written permission.
 #   *
 #   * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 #   * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 #   * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
 #   * FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
 #   * REGENTS OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
 #   * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 #   * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 #   * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 #   * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
 #   * STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 #   * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
 #   * OF THE POSSIBILITY OF SUCH DAMAGE.
 #   */
 #
 #  Copyright 1996 Chih-Hao Tsai @ Beckman Institute,
 #      University of Illinois
 #  c-tsai4@uiuc.edu  http://casper.beckman.uiuc.edu/~c-tsai4
 #
 #  ---------------COPYING.libtabe-----END--------------------------------
 #
 #
 #  ---------------COPYING.ipadic-----BEGIN-------------------------------
 #
 #  Copyright 2000, 2001, 2002, 2003 Nara Institute of Science
 #  and Technology.  All Rights Reserved.
 #
 #  Use, reproduction, and distribution of this software is permitted.
 #  Any copy of this software, whether in its original form or modified,
 #  must include both the above copyright notice and the following
 #  paragraphs.
 #
 #  Nara Institute of Science and Technology (NAIST),
 #  the copyright holders, disclaims all warranties with regard to this
 #  software, including all implied warranties of merchantability and
 #  fitness, in no event shall NAIST be liable for
 #  any special, indirect or consequential damages or any damages
 #  whatsoever resulting from loss of use, data or profits, whether in an
 #  action of contract, negligence or other tortuous action, arising out
 #  of or in connection with the use or performance of this software.
 #
 #  A large portion of the dictionary entries
 #  originate from ICOT Free Software.  The following conditions for ICOT
 #  Free Software applies to the current dictionary as well.
 #
 #  Each User may also freely distribute the Program, whether in its
 #  original form or modified, to any third party or parties, PROVIDED
 #  that the provisions of Section 3 ("NO WARRANTY") will ALWAYS appear
 #  on, or be attached to, the Program, which is distributed substantially
 #  in the same form as set out herein and that such intended
 #  distribution, if actually made, will neither violate or otherwise
 #  contravene any of the laws and regulations of the countries having
 #  jurisdiction over the User or the intended distribution itself.
 #
 #  NO WARRANTY
 #
 #  The program was produced on an experimental basis in the course of the
 #  research and development conducted during the project and is provided
 #  to users as so produced on an experimental basis.  Accordingly, the
 #  program is provided without any warranty whatsoever, whether express,
 #  implied, statutory or otherwise.  The term "warranty" used herein
 #  includes, but is not limited to, any warranty of the quality,
 #  performance, merchantability and fitness for a particular purpose of
 #  the program and the nonexistence of any infringement or violation of
 #  any right of any third party.
 #
 #  Each user of the program will agree and understand, and be deemed to
 #  have agreed and understood, that there is no warranty whatsoever for
 #  the program and, accordingly, the entire risk arising from or
 #  otherwise connected with the program is assumed by the user.
 #
 #  Therefore, neither ICOT, the copyright holder, or any other
 #  organization that participated in or was otherwise related to the
 #  development of the program and their respective officials, directors,
 #  officers and other employees shall be held liable for any and all
 #  damages, including, without limitation, general, special, incidental
 #  and consequential damages, arising out of or otherwise in connection
 #  with the use or inability to use the program or any product, material
 #  or result produced or otherwise obtained by using the program,
 #  regardless of whether they have been advised of, or otherwise had
 #  knowledge of, the possibility of such damages at any time during the
 #  project or thereafter.  Each user will be deemed to have agreed to the
 #  foregoing by his or her commencement of use of the program.  The term
 #  "use" as used herein includes, but is not limited to, the use,
 #  modification, copying and distribution of the program and the
 #  production of secondary products from the program.
 #
 #  In the case where the program, whether in its original form or
 #  modified, was distributed or delivered to or received by a user from
 #  any person, organization or entity other than ICOT, unless it makes or
 #  grants independently of ICOT any specific warranty to the user in
 #  writing, such person, organization or entity, will also be exempted
 #  from and not be held liable to the user for any such damages as noted
 #  above as far as the program is concerned.
 #
 #  ---------------COPYING.ipadic-----END----------------------------------

3. Lao Word Break Dictionary Data (laodict.txt)

 #  Copyright (c) 2013 International Business Machines Corporation
 #  and others. All Rights Reserved.
 #
 # Project: http://code.google.com/p/lao-dictionary/
 # Dictionary: http://lao-dictionary.googlecode.com/git/Lao-Dictionary.txt
 # License: http://lao-dictionary.googlecode.com/git/Lao-Dictionary-LICENSE.txt
 #              (copied below)
 #
 #  This file is derived from the above dictionary, with slight
 #  modifications.
 #  ----------------------------------------------------------------------
 #  Copyright (C) 2013 Brian Eugene Wilson, Robert Martin Campbell.
 #  All rights reserved.
 #
 #  Redistribution and use in source and binary forms, with or without
 #  modification,
 #  are permitted provided that the following conditions are met:
 #
 #
 # Redistributions of source code must retain the above copyright notice, this
 #  list of conditions and the following disclaimer. Redistributions in
 #  binary form must reproduce the above copyright notice, this list of
 #  conditions and the following disclaimer in the documentation and/or
 #  other materials provided with the distribution.
 #
 #
 # THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 # "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 # LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
 # FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
 # COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 # INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 # (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 # SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 # HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
 # STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 # ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
 # OF THE POSSIBILITY OF SUCH DAMAGE.
 #  --------------------------------------------------------------------------

4. Burmese Word Break Dictionary Data (burmesedict.txt)

 #  Copyright (c) 2014 International Business Machines Corporation
 #  and others. All Rights Reserved.
 #
 #  This list is part of a project hosted at:
 #    github.com/kanyawtech/myanmar-karen-word-lists
 #
 #  --------------------------------------------------------------------------
 #  Copyright (c) 2013, LeRoy Benjamin Sharon
 #  All rights reserved.
 #
 #  Redistribution and use in source and binary forms, with or without
 #  modification, are permitted provided that the following conditions
 #  are met: Redistributions of source code must retain the above
 #  copyright notice, this list of conditions and the following
 #  disclaimer.  Redistributions in binary form must reproduce the
 #  above copyright notice, this list of conditions and the following
 #  disclaimer in the documentation and/or other materials provided
 #  with the distribution.
 #
 #    Neither the name Myanmar Karen Word Lists, nor the names of its
 #    contributors may be used to endorse or promote products derived
 #    from this software without specific prior written permission.
 #
 #  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND
 #  CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES,
 #  INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 #  MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 #  DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS
 #  BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 #  EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
 #  TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 #  DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
 #  ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR
 #  TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF
 #  THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 #  SUCH DAMAGE.
 #  --------------------------------------------------------------------------

5. Time Zone Database

  ICU uses the public domain data and code derived from Time Zone
Database for its time zone support. The ownership of the TZ database
is explained in BCP 175: Procedure for Maintaining the Time Zone
Database section 7.

 # 7.  Database Ownership
 #
 #    The TZ database itself is not an IETF Contribution or an IETF
 #    document.  Rather it is a pre-existing and regularly updated work
 #    that is in the public domain, and is intended to remain in the
 #    public domain.  Therefore, BCPs 78 [RFC5378] and 79 [RFC3979] do
 #    not apply to the TZ Database or contributions that individuals make
 #    to it.  Should any claims be made and substantiated against the TZ
 #    Database, the organization that is providing the IANA
 #    Considerations defined in this RFC, under the memorandum of
 #    understanding with the IETF, currently ICANN, may act in accordance
 #    with all competent court orders.  No ownership claims will be made
 #    by ICANN or the IETF Trust on the database or the code.  Any person
 #    making a contribution to the database or code waives all rights to
 #    future claims in that contribution or in the TZ Database.

6. Google double-conversion

Copyright 2006-2011, the V8 project authors. All rights reserved.
Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are
met:

    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above
      copyright notice, this list of conditions and the following
      disclaimer in the documentation and/or other materials provided
      with the distribution.
    * Neither the name of Google Inc. nor the names of its
      contributors may be used to endorse or promote products derived
      from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
"AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
```

### lib/src/portable/endian.h

The licence comment of `lib/src/portable/endian.h`, which the runtime compiles in:

```text
// "License": Public Domain
// I, Mathias Panzenböck, place this file hereby into the public domain. Use it at your own risk for whatever you like.
// In case there are jurisdictions that don't support putting things in the public domain you can also consider it to
// be "dual licensed" under the BSD, MIT and Apache licenses, if you want to. This code is trivial anyway. Consider it
// an example on how to get the endian conversion functions on different platforms.
```

## Grammars

Each grammar library is compiled from its repository at the commit named, and that repository's licence covers it.

### tree-sitter-c

`libc.dylib` is compiled from https://github.com/tree-sitter/tree-sitter-c at ae19b676b13bdcc13b7665397e6d9b14975473dd. Licence: MIT.

#### LICENSE

```text
The MIT License (MIT)

Copyright (c) 2014 Max Brunsfeld

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

### tree-sitter-cpp

`libcpp.dylib` is compiled from https://github.com/tree-sitter/tree-sitter-cpp at 12bd6f7e96080d2e70ec51d4068f2f66120dde35. Licence: MIT.

#### LICENSE

```text
The MIT License (MIT)

Copyright (c) 2014 Max Brunsfeld

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

### tree-sitter-c-sharp

`libc-sharp.dylib` is compiled from https://github.com/tree-sitter/tree-sitter-c-sharp at f05a2ca99d329de2e6c32f26a21c6169b2bfcbb7. Licence: MIT.

#### LICENSE

```text
The MIT License (MIT)

Copyright (c) 2014-2023 Max Brunsfeld, Damien Guard, Amaan Qureshi, and contributors.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

### tree-sitter-css

`libcss.dylib` is compiled from https://github.com/tree-sitter/tree-sitter-css at dda5cfc5722c429eaba1c910ca32c2c0c5bb1a3f. Licence: MIT.

#### LICENSE

```text
The MIT License (MIT)

Copyright (c) 2018 Max Brunsfeld

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

### tree-sitter-go

`libgo.dylib` is compiled from https://github.com/tree-sitter/tree-sitter-go at 2346a3ab1bb3857b48b29d779a1ef9799a248cd7. Licence: MIT.

#### LICENSE

```text
The MIT License (MIT)

Copyright (c) 2014 Max Brunsfeld

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

### tree-sitter-haskell

`libhaskell.dylib` is compiled from https://github.com/tree-sitter/tree-sitter-haskell at 0975ef72fc3c47b530309ca93937d7d143523628. Licence: MIT.

#### LICENSE

```text
The MIT License (MIT)

Copyright (c) 2014 Max Brunsfeld

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

### tree-sitter-html

`libhtml.dylib` is compiled from https://github.com/tree-sitter/tree-sitter-html at 73a3947324f6efddf9e17c0ea58d454843590cc0. Licence: MIT.

#### LICENSE

```text
The MIT License (MIT)

Copyright (c) 2014 Max Brunsfeld

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

### tree-sitter-java

`libjava.dylib` is compiled from https://github.com/tree-sitter/tree-sitter-java at e10607b45ff745f5f876bfa3e94fbcc6b44bdc11. Licence: MIT.

#### LICENSE

```text
MIT License

Copyright (c) 2017 Ayman Nadeem

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

### tree-sitter-javascript

`libjavascript.dylib` is compiled from https://github.com/tree-sitter/tree-sitter-javascript at 58404d8cf191d69f2674a8fd507bd5776f46cb11. Licence: MIT.

#### LICENSE

```text
The MIT License (MIT)

Copyright (c) 2014 Max Brunsfeld

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

### tree-sitter-jsdoc

`libjsdoc.dylib` is compiled from https://github.com/tree-sitter/tree-sitter-jsdoc at 658d18dcdddb75c760363faa4963427a7c6b52db. Licence: MIT.

#### LICENSE

```text
The MIT License (MIT)

Copyright (c) 2018 Max Brunsfeld <maxbrunsfeld@gmail.com>

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

### tree-sitter-json

`libjson.dylib` is compiled from https://github.com/tree-sitter/tree-sitter-json at 001c28d7a29832b06b0e831ec77845553c89b56d. Licence: MIT.

#### LICENSE

```text
The MIT License (MIT)

Copyright (c) 2014 Max Brunsfeld

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

### tree-sitter-ocaml

`libocaml.dylib` is compiled from https://github.com/tree-sitter/tree-sitter-ocaml at 3ef7c00b29e41e3a0c1d18e82ea37c64d72b93fc. Licence: MIT.

#### LICENSE

```text
MIT License

Copyright (c) 2020 Max Brunsfeld and Pieter Goetschalckx

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

### tree-sitter-php

`libphp.dylib` is compiled from https://github.com/tree-sitter/tree-sitter-php at 7d07b41ce2d442ca9a90ed85d0075eccc17ae315. Licence: MIT.

#### LICENSE

```text
The MIT License (MIT)

Copyright (c) 2017 Josh Vera, GitHub
Copyright (c) 2019 Max Brunsfeld, Amaan Qureshi, Christian Frøystad, Caleb White

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

### tree-sitter-python

`libpython.dylib` is compiled from https://github.com/tree-sitter/tree-sitter-python at 26855eabccb19c6abf499fbc5b8dc7cc9ab8bc64. Licence: MIT.

#### LICENSE

```text
The MIT License (MIT)

Copyright (c) 2016 Max Brunsfeld

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

### tree-sitter-regex

`libregex.dylib` is compiled from https://github.com/tree-sitter/tree-sitter-regex at b2ac15e27fce703d2f37a79ccd94a5c0cbe9720b. Licence: MIT.

#### LICENSE

```text
The MIT License (MIT)

Copyright (c) 2014 Max Brunsfeld

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

### tree-sitter-ruby

`libruby.dylib` is compiled from https://github.com/tree-sitter/tree-sitter-ruby at ab6dca77a8184abc94af6e3e82538741b5078d63. Licence: MIT.

#### LICENSE

```text
The MIT License (MIT)

Copyright (c) 2016 Rob Rix

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

```

### tree-sitter-rust

`librust.dylib` is compiled from https://github.com/tree-sitter/tree-sitter-rust at 261b20226c04ef601adbdf185a800512a5f66291. Licence: MIT.

#### LICENSE

```text
The MIT License (MIT)

Copyright (c) 2017 Maxim Sokolov

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

### tree-sitter-scala

`libscala.dylib` is compiled from https://github.com/tree-sitter/tree-sitter-scala at 97aead18d97708190a51d4f551ea9b05b60641c9. Licence: MIT.

#### LICENSE

```text
The MIT License (MIT)

Copyright (c) 2018 Max Brunsfeld and GitHub

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

### tree-sitter-typescript

`libtypescript.dylib` and `libtsx.dylib` are compiled from https://github.com/tree-sitter/tree-sitter-typescript at 75b3874edb2dc714fb1fd77a32013d0f8699989f. Licence: MIT.

#### LICENSE

```text
The MIT License (MIT)

Copyright (c) 2017 Max Brunsfeld

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

### tree-sitter-dart

`libdart.dylib` is compiled from https://github.com/UserNobody14/tree-sitter-dart at d4d8f3e337d8be23be27ffc35a0aef972343cd54. Licence: MIT.

#### LICENSE

```text
Copyright (c) 2020-2023 UserNobody14 and others

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
```

### tree-sitter-ada

`libada.dylib` is compiled from https://github.com/briot/tree-sitter-ada at 6b58259a08b1a22ba0247a7ce30be384db618da6. Licence: MIT.

#### LICENSE.txt

```text
MIT License

Copyright (c) 2023 Emmanuel Briot

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

### tree-sitter-bash

`libbash.dylib` is compiled from https://github.com/tree-sitter/tree-sitter-bash at a06c2e4415e9bc0346c6b86d401879ffb44058f7. Licence: MIT.

#### LICENSE

```text
The MIT License (MIT)

Copyright (c) 2017 Max Brunsfeld

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

### tree-sitter-make

`libmake.dylib` is compiled from https://github.com/tree-sitter-grammars/tree-sitter-make at 5e9e8f8ff3387b0edcaa90f46ddf3629f4cfeb1d. Licence: MIT.

#### LICENSE

```text
MIT License

Copyright (c) 2021 Alexandre A. Muller

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

### tree-sitter-yaml

`libyaml.dylib` is compiled from https://github.com/tree-sitter-grammars/tree-sitter-yaml at 7708026449bed86239b1cd5bce6e3c34dbca6415. Licence: MIT.

#### LICENSE

```text
Copyright (c) 2024 tree-sitter-grammars contributors
Copyright (c) 2019-2021 Ika

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

### tree-sitter-toml

`libtoml.dylib` is compiled from https://github.com/tree-sitter-grammars/tree-sitter-toml at 64b56832c2cffe41758f28e05c756a3a98d16f41. Licence: MIT.

#### LICENSE

```text
The MIT License (MIT)

Copyright (c) Ika <ikatyang@gmail.com> (https://github.com/ikatyang)

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

### tree-sitter-commonlisp

`libcommonlisp.dylib` is compiled from https://github.com/tree-sitter-grammars/tree-sitter-commonlisp at 32323509b3d9fe96607d151c2da2c9009eb13a2f. Licence: MIT.

#### LICENSE.md

```text
The MIT License (MIT)

Copyright (c) 2021 Stephan Seitz

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

### tree-sitter-sql

`libsql.dylib` is compiled from https://github.com/DerekStride/tree-sitter-sql at 5129061608da71146c813e13c32a54f4b13645c8, deployed from 39489e8728db978f832b24873e995023fcd8e5c3. Licence: MIT.

#### LICENSE

```text
MIT License

Copyright (c) 2021 Derek Stride

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

### tree-sitter-csv

`libcsv.dylib` is compiled from https://github.com/tree-sitter-grammars/tree-sitter-csv at f6bf6e35eb0b95fbadea4bb39cb9709507fcb181. Licence: MIT.

#### LICENSE

```text
The MIT License (MIT)

Copyright (c) 2023 Amaan Qureshi <amaanq12@gmail.com>

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

### tree-sitter-diff

`libdiff.dylib` is compiled from https://github.com/the-mikedavis/tree-sitter-diff at 2520c3f934b3179bb540d23e0ef45f75304b5fed. Licence: MIT.

#### LICENSE

```text
MIT License

Copyright (c) 2021 Michael Davis

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

### tree-sitter-lua

`liblua.dylib` is compiled from https://github.com/tree-sitter-grammars/tree-sitter-lua at e284fcec45ead0d477e326fccd2cd4a68a89dae4. Licence: MIT.

#### LICENSE.md

```text
The MIT License (MIT)

Copyright (c) 2021 Munif Tanjim

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

### tree-sitter-idl

`libidl.dylib` is compiled from https://github.com/cathaysia/tree-sitter-idl at e6b8b4d2ba285caacf6f9e931f1f637f5bc02b03. Licence: Apache-2.0.

#### LICENSE

```text
                              Apache License
                        Version 2.0, January 2004
                     http://www.apache.org/licenses/

TERMS AND CONDITIONS FOR USE, REPRODUCTION, AND DISTRIBUTION

1. Definitions.

   "License" shall mean the terms and conditions for use, reproduction,
   and distribution as defined by Sections 1 through 9 of this document.

   "Licensor" shall mean the copyright owner or entity authorized by
   the copyright owner that is granting the License.

   "Legal Entity" shall mean the union of the acting entity and all
   other entities that control, are controlled by, or are under common
   control with that entity. For the purposes of this definition,
   "control" means (i) the power, direct or indirect, to cause the
   direction or management of such entity, whether by contract or
   otherwise, or (ii) ownership of fifty percent (50%) or more of the
   outstanding shares, or (iii) beneficial ownership of such entity.

   "You" (or "Your") shall mean an individual or Legal Entity
   exercising permissions granted by this License.

   "Source" form shall mean the preferred form for making modifications,
   including but not limited to software source code, documentation
   source, and configuration files.

   "Object" form shall mean any form resulting from mechanical
   transformation or translation of a Source form, including but
   not limited to compiled object code, generated documentation,
   and conversions to other media types.

   "Work" shall mean the work of authorship, whether in Source or
   Object form, made available under the License, as indicated by a
   copyright notice that is included in or attached to the work
   (an example is provided in the Appendix below).

   "Derivative Works" shall mean any work, whether in Source or Object
   form, that is based on (or derived from) the Work and for which the
   editorial revisions, annotations, elaborations, or other modifications
   represent, as a whole, an original work of authorship. For the purposes
   of this License, Derivative Works shall not include works that remain
   separable from, or merely link (or bind by name) to the interfaces of,
   the Work and Derivative Works thereof.

   "Contribution" shall mean any work of authorship, including
   the original version of the Work and any modifications or additions
   to that Work or Derivative Works thereof, that is intentionally
   submitted to Licensor for inclusion in the Work by the copyright owner
   or by an individual or Legal Entity authorized to submit on behalf of
   the copyright owner. For the purposes of this definition, "submitted"
   means any form of electronic, verbal, or written communication sent
   to the Licensor or its representatives, including but not limited to
   communication on electronic mailing lists, source code control systems,
   and issue tracking systems that are managed by, or on behalf of, the
   Licensor for the purpose of discussing and improving the Work, but
   excluding communication that is conspicuously marked or otherwise
   designated in writing by the copyright owner as "Not a Contribution."

   "Contributor" shall mean Licensor and any individual or Legal Entity
   on behalf of whom a Contribution has been received by Licensor and
   subsequently incorporated within the Work.

2. Grant of Copyright License. Subject to the terms and conditions of
   this License, each Contributor hereby grants to You a perpetual,
   worldwide, non-exclusive, no-charge, royalty-free, irrevocable
   copyright license to reproduce, prepare Derivative Works of,
   publicly display, publicly perform, sublicense, and distribute the
   Work and such Derivative Works in Source or Object form.

3. Grant of Patent License. Subject to the terms and conditions of
   this License, each Contributor hereby grants to You a perpetual,
   worldwide, non-exclusive, no-charge, royalty-free, irrevocable
   (except as stated in this section) patent license to make, have made,
   use, offer to sell, sell, import, and otherwise transfer the Work,
   where such license applies only to those patent claims licensable
   by such Contributor that are necessarily infringed by their
   Contribution(s) alone or by combination of their Contribution(s)
   with the Work to which such Contribution(s) was submitted. If You
   institute patent litigation against any entity (including a
   cross-claim or counterclaim in a lawsuit) alleging that the Work
   or a Contribution incorporated within the Work constitutes direct
   or contributory patent infringement, then any patent licenses
   granted to You under this License for that Work shall terminate
   as of the date such litigation is filed.

4. Redistribution. You may reproduce and distribute copies of the
   Work or Derivative Works thereof in any medium, with or without
   modifications, and in Source or Object form, provided that You
   meet the following conditions:

   (a) You must give any other recipients of the Work or
       Derivative Works a copy of this License; and

   (b) You must cause any modified files to carry prominent notices
       stating that You changed the files; and

   (c) You must retain, in the Source form of any Derivative Works
       that You distribute, all copyright, patent, trademark, and
       attribution notices from the Source form of the Work,
       excluding those notices that do not pertain to any part of
       the Derivative Works; and

   (d) If the Work includes a "NOTICE" text file as part of its
       distribution, then any Derivative Works that You distribute must
       include a readable copy of the attribution notices contained
       within such NOTICE file, excluding those notices that do not
       pertain to any part of the Derivative Works, in at least one
       of the following places: within a NOTICE text file distributed
       as part of the Derivative Works; within the Source form or
       documentation, if provided along with the Derivative Works; or,
       within a display generated by the Derivative Works, if and
       wherever such third-party notices normally appear. The contents
       of the NOTICE file are for informational purposes only and
       do not modify the License. You may add Your own attribution
       notices within Derivative Works that You distribute, alongside
       or as an addendum to the NOTICE text from the Work, provided
       that such additional attribution notices cannot be construed
       as modifying the License.

   You may add Your own copyright statement to Your modifications and
   may provide additional or different license terms and conditions
   for use, reproduction, or distribution of Your modifications, or
   for any such Derivative Works as a whole, provided Your use,
   reproduction, and distribution of the Work otherwise complies with
   the conditions stated in this License.

5. Submission of Contributions. Unless You explicitly state otherwise,
   any Contribution intentionally submitted for inclusion in the Work
   by You to the Licensor shall be under the terms and conditions of
   this License, without any additional terms or conditions.
   Notwithstanding the above, nothing herein shall supersede or modify
   the terms of any separate license agreement you may have executed
   with Licensor regarding such Contributions.

6. Trademarks. This License does not grant permission to use the trade
   names, trademarks, service marks, or product names of the Licensor,
   except as required for reasonable and customary use in describing the
   origin of the Work and reproducing the content of the NOTICE file.

7. Disclaimer of Warranty. Unless required by applicable law or
   agreed to in writing, Licensor provides the Work (and each
   Contributor provides its Contributions) on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
   implied, including, without limitation, any warranties or conditions
   of TITLE, NON-INFRINGEMENT, MERCHANTABILITY, or FITNESS FOR A
   PARTICULAR PURPOSE. You are solely responsible for determining the
   appropriateness of using or redistributing the Work and assume any
   risks associated with Your exercise of permissions under this License.

8. Limitation of Liability. In no event and under no legal theory,
   whether in tort (including negligence), contract, or otherwise,
   unless required by applicable law (such as deliberate and grossly
   negligent acts) or agreed to in writing, shall any Contributor be
   liable to You for damages, including any direct, indirect, special,
   incidental, or consequential damages of any character arising as a
   result of this License or out of the use or inability to use the
   Work (including but not limited to damages for loss of goodwill,
   work stoppage, computer failure or malfunction, or any and all
   other commercial damages or losses), even if such Contributor
   has been advised of the possibility of such damages.

9. Accepting Warranty or Additional Liability. While redistributing
   the Work or Derivative Works thereof, You may choose to offer,
   and charge a fee for, acceptance of support, warranty, indemnity,
   or other liability obligations and/or rights consistent with this
   License. However, in accepting such obligations, You may act only
   on Your own behalf and on Your sole responsibility, not on behalf
   of any other Contributor, and only if You agree to indemnify,
   defend, and hold each Contributor harmless for any liability
   incurred by, or claims asserted against, such Contributor by reason
   of your accepting any such warranty or additional liability.

END OF TERMS AND CONDITIONS

APPENDIX: How to apply the Apache License to your work.

   To apply the Apache License to your work, attach the following
   boilerplate notice, with the fields enclosed by brackets "[]"
   replaced with your own identifying information. (Don't include
   the brackets!)  The text should be enclosed in the appropriate
   comment syntax for the file format. We also recommend that a
   file or class name and description of purpose be included on the
   same "printed page" as the copyright notice for easier
   identification within third-party archives.

Copyright [yyyy] [name of copyright owner]

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

	http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
```

### tree-sitter-javadoc

`libjavadoc.dylib` is compiled from https://github.com/rmuir/tree-sitter-javadoc at 373fbd84f35aff70031426ed6edf3cdf52b93532. Licence: MIT.

#### LICENSE

```text
The MIT License (MIT)

Copyright (c) 2025 Robert Muir

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

### tree-sitter-kotlin

`libkotlin.dylib` is compiled from https://github.com/fwcd/tree-sitter-kotlin at 57fb4560ba8641865bc0baa6b3f413b236112c4c. Licence: MIT.

#### LICENSE

```text
The MIT License (MIT)

Copyright (c) 2019 fwcd

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
```

### tree-sitter-objc

`libobjc.dylib` is compiled from https://github.com/tree-sitter-grammars/tree-sitter-objc at 181a81b8f23a2d593e7ab4259981f50122909fda. Licence: MIT.

#### LICENSE

```text
The MIT License (MIT)

Copyright (c) 2023 Amaan Qureshi <amaanq12@gmail.com>

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

### tree-sitter-swift

`libswift.dylib` is compiled from https://github.com/alex-pinkus/tree-sitter-swift at 8abb3e8b33256d89127a35e87480736f74755ff9. Licence: MIT.

#### LICENSE

```text
MIT License

Copyright (c) 2021 alex-pinkus

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

### tree-sitter-pascal

`libpascal.dylib` is compiled from https://github.com/Isopod/tree-sitter-pascal at 042119eca2e18a60e56317fb06ee3ba5c32cb447. Licence: MIT.

#### LICENSE

```text
MIT License

Copyright (c) 2018 Benjamin Gray

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

### tree-sitter-perl

`libperl.dylib` is compiled from https://github.com/tree-sitter-perl/tree-sitter-perl at 0c24d001dd1921e418fb933d208a7bd7dd3f923a, deployed from ad74e6db234c35d537de9358799a8e0cc4f5dee0. Licence: MIT.

#### LICENSE

```text
Copyright 2025 Avishai "Veesh" Goldman

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the “Software”), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
```

#### src/bsearch.h

The licence comment of `src/bsearch.h`, which the library compiles in:

```text
/*
 * Copyright (c) 1990 Regents of the University of California.
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. [rescinded 22 July 1999]
 * 4. Neither the name of the University nor the names of its contributors
 *    may be used to endorse or promote products derived from this software
 *    without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */
```

### tree-sitter-proto

`libproto.dylib` is compiled from https://github.com/treywood/tree-sitter-proto at e9f6b43f6844bd2189b50a422d4e2094313f6aa3. Licence: MIT.

#### LICENSE

```text
MIT License

Copyright (c) 2021 Mitchell Hashimoto

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

### tree-sitter-scheme

`libscheme.dylib` is compiled from https://github.com/6cdh/tree-sitter-scheme at b5c701148501fa056302827442b5b4956f1edc03. Licence: MIT.

#### LICENSE

```text
MIT License

Copyright (c) 2022 6cdh

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

```

### tree-sitter-thrift

`libthrift.dylib` is compiled from https://github.com/tree-sitter-grammars/tree-sitter-thrift at 68fd0d80943a828d9e6f49c58a74be1e9ca142cf. Licence: MIT.

#### LICENSE

```text
The MIT License (MIT)

Copyright (c) 2023 Amaan Qureshi <amaanq12@gmail.com>, Campbell He <kp.campbell.he@duskmoon314.com>

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

### tree-sitter-xml

`libxml.dylib` and `libdtd.dylib` are compiled from https://github.com/tree-sitter-grammars/tree-sitter-xml at 5000ae8f22d11fbe93939b05c1e37cf21117162d. Licence: MIT.

#### LICENSE

```text
Copyright (c) 2023 ObserverOfTime

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

### tree-sitter-zig

`libzig.dylib` is compiled from https://github.com/tree-sitter-grammars/tree-sitter-zig at 6479aa13f32f701c383083d8b28360ebd682fb7d. Licence: MIT.

#### LICENSE

```text
The MIT License (MIT)

Copyright (c) 2024 Amaan Qureshi <amaanq12@gmail.com>

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

### tree-sitter-markdown

`libmarkdown.dylib` and `libmarkdown_inline.dylib` are compiled from https://github.com/tree-sitter-grammars/tree-sitter-markdown at 2dfd57f547f06ca5631a80f601e129d73fc8e9f0. Licence: MIT.

#### LICENSE

```text
MIT License

Copyright (c) 2021 Matthias Deiml

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

### tree-sitter-mermaid

`libmermaid.dylib` is compiled from https://github.com/mikkihugo/tree-sitter-mermaid at 939e7b23159637ff836561e18c93e2a2e406acf0. Licence: MIT.

#### LICENSE

```text
MIT License

Copyright (c) 2022 Mogami Shinichi
Copyright (c) 2025 Mikael Hugo

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

### tree-sitter-latex

`liblatex.dylib` is compiled from https://github.com/latex-lsp/tree-sitter-latex at 7e0ecdc02926c7b9b2e0c76003d4fe7b0944f957. Licence: MIT.

#### LICENSE

```text
MIT License

Copyright (c) 2021 Patrick Förster

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

### tree-sitter-comment

`libcomment.dylib` is compiled from https://github.com/stsewd/tree-sitter-comment at 66272d2b6c73fb61157541b69dd0a7ce7b42a5ad. Licence: MIT.

#### LICENSE

```text
MIT License

Copyright (c) 2021 Santos Gallegos

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## Query files

Every query file came from one of three places: nvim-treesitter, a grammar's own repository, or tree-sitter-grammars itself. A file can carry lines from both of the first two.

### Derived from nvim-treesitter

These files are derived from https://github.com/nvim-treesitter/nvim-treesitter, under the Apache License 2.0 reproduced below, which is nvim-treesitter's `LICENSE` at every commit named. Each one names, in a header at its top, the nvim-treesitter file and commit it derives from and whether tree-sitter-grammars modified it.

| File | nvim-treesitter file | Commit | State |
| --- | --- | --- | --- |
| `ada/folds.scm` | `runtime/queries/ada/folds.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | modified in tree-sitter-grammars |
| `ada/highlights.scm` | `runtime/queries/ada/highlights.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | modified in tree-sitter-grammars |
| `ada/injections.scm` | `runtime/queries/ada/injections.scm` | `aaf5b7fdf7664581601063f7804cff02e849525e` | unchanged |
| `ada/locals.scm` | `runtime/queries/ada/locals.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | unchanged |
| `bash/folds.scm` | `runtime/queries/bash/folds.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | modified in tree-sitter-grammars |
| `bash/indents.scm` | `runtime/queries/bash/indents.scm` | `433779916223596dce3ea64f4b77300c3aa2bfdc` | modified in tree-sitter-grammars |
| `bash/injections.scm` | `runtime/queries/bash/injections.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | modified in tree-sitter-grammars |
| `bash/locals.scm` | `runtime/queries/bash/locals.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | unchanged |
| `c-sharp/folds.scm` | `runtime/queries/c_sharp/folds.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | unchanged |
| `c-sharp/injections.scm` | `runtime/queries/c_sharp/injections.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | unchanged |
| `c-sharp/locals.scm` | `runtime/queries/c_sharp/locals.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | unchanged |
| `c/folds.scm` | `runtime/queries/c/folds.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | modified in tree-sitter-grammars |
| `c/indents.scm` | `runtime/queries/c/indents.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | modified in tree-sitter-grammars |
| `c/injections.scm` | `runtime/queries/c/injections.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | modified in tree-sitter-grammars |
| `c/locals.scm` | `runtime/queries/c/locals.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | modified in tree-sitter-grammars |
| `comment/highlights.scm` | `runtime/queries/comment/highlights.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | modified in tree-sitter-grammars |
| `commonlisp/highlights.scm` | `queries/commonlisp/highlights.scm` | `d198a75e2c2e24885b05650515538d055d0c64e4` | modified in tree-sitter-grammars |
| `commonlisp/injections.scm` | `runtime/queries/commonlisp/injections.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | unchanged |
| `commonlisp/locals.scm` | `runtime/queries/commonlisp/locals.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | modified in tree-sitter-grammars |
| `cpp/folds.scm` | `runtime/queries/cpp/folds.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | modified in tree-sitter-grammars |
| `cpp/indents.scm` | `runtime/queries/cpp/indents.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | modified in tree-sitter-grammars |
| `cpp/injections.scm` | `queries/cpp/injections.scm` | `b5f203031282a6e9e025080fe71b58dbb43f7509` | modified in tree-sitter-grammars |
| `cpp/locals.scm` | `runtime/queries/cpp/locals.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | modified in tree-sitter-grammars |
| `css/folds.scm` | `runtime/queries/css/folds.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | unchanged |
| `css/indents.scm` | `runtime/queries/css/indents.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | modified in tree-sitter-grammars |
| `css/injections.scm` | `runtime/queries/css/injections.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | unchanged |
| `csv/highlights.scm` | `runtime/queries/csv/highlights.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | modified in tree-sitter-grammars |
| `dart/folds.scm` | `runtime/queries/dart/folds.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | unchanged |
| `dart/indents.scm` | `runtime/queries/dart/indents.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | modified in tree-sitter-grammars |
| `dart/injections.scm` | `runtime/queries/dart/injections.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | modified in tree-sitter-grammars |
| `dart/locals.scm` | `runtime/queries/dart/locals.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | unchanged |
| `diff/folds.scm` | `runtime/queries/diff/folds.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | unchanged |
| `diff/highlights.scm` | `runtime/queries/diff/highlights.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | modified in tree-sitter-grammars |
| `diff/injections.scm` | `runtime/queries/diff/injections.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | unchanged |
| `dtd/folds.scm` | `runtime/queries/dtd/folds.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | unchanged |
| `dtd/highlights.scm` | `runtime/queries/dtd/highlights.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | modified in tree-sitter-grammars |
| `dtd/injections.scm` | `runtime/queries/dtd/injections.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | unchanged |
| `dtd/locals.scm` | `runtime/queries/dtd/locals.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | unchanged |
| `ecma/folds.scm` | `runtime/queries/ecma/folds.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | modified in tree-sitter-grammars |
| `ecma/highlights.scm` | `runtime/queries/ecma/highlights.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | modified in tree-sitter-grammars |
| `ecma/indents.scm` | `runtime/queries/ecma/indents.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | modified in tree-sitter-grammars |
| `ecma/injections.scm` | `runtime/queries/ecma/injections.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | modified in tree-sitter-grammars |
| `go/folds.scm` | `runtime/queries/go/folds.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | modified in tree-sitter-grammars |
| `go/indents.scm` | `runtime/queries/go/indents.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | modified in tree-sitter-grammars |
| `go/injections.scm` | `runtime/queries/go/injections.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | modified in tree-sitter-grammars |
| `go/locals.scm` | `runtime/queries/go/locals.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | modified in tree-sitter-grammars |
| `haskell/highlights.scm` | `runtime/queries/haskell/highlights.scm` | `d6ebbd5039954ecd47463802a16b5d8d7f223eef` | by way of the grammar's file below |
| `haskell/injections.scm` | `queries/haskell/injections.scm` | `77e298e4de607d69aa7f37dc6dcba6aee131ac7f` | by way of the grammar's file below |
| `html/folds.scm` | `runtime/queries/html/folds.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | unchanged |
| `html/highlights.scm` | `runtime/queries/html/highlights.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | unchanged |
| `html/indents.scm` | `runtime/queries/html/indents.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | unchanged |
| `html/injections.scm` | `runtime/queries/html/injections.scm` | `f2204e58dbb2031cb6783caa4541c4483edbb426` | modified in tree-sitter-grammars |
| `html/locals.scm` | `runtime/queries/html/locals.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | unchanged |
| `html_tags/highlights.scm` | `queries/html_tags/highlights.scm` | `f7c05e3e0510df7c742d455c802e27b6ee7ab384` | modified in tree-sitter-grammars |
| `html_tags/indents.scm` | `runtime/queries/html_tags/indents.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | modified in tree-sitter-grammars |
| `html_tags/injections.scm` | `runtime/queries/html_tags/injections.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | modified in tree-sitter-grammars |
| `idl/highlights.scm` | `runtime/queries/idl/highlights.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | unchanged |
| `idl/indents.scm` | `runtime/queries/idl/indents.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | modified in tree-sitter-grammars |
| `idl/injections.scm` | `runtime/queries/idl/injections.scm` | `864e75a85d4bbe77745929a1ce4d4c63bef11480` | modified in tree-sitter-grammars |
| `java/folds.scm` | `runtime/queries/java/folds.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | unchanged |
| `java/highlights.scm` | `queries/java/highlights.scm` | `bcf421b4e7f164dfc8aca8a94949adda2bdda10f` | by way of the grammar's file below |
| `java/indents.scm` | `runtime/queries/java/indents.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | modified in tree-sitter-grammars |
| `java/injections.scm` | `runtime/queries/java/injections.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | modified in tree-sitter-grammars |
| `java/locals.scm` | `runtime/queries/java/locals.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | unchanged |
| `javadoc/indents.scm` | `runtime/queries/javadoc/indents.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | unchanged |
| `javadoc/injections.scm` | `runtime/queries/javadoc/injections.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | modified in tree-sitter-grammars |
| `javascript/folds.scm` | `runtime/queries/javascript/folds.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | unchanged |
| `javascript/indents.scm` | `runtime/queries/javascript/indents.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | unchanged |
| `javascript/locals.scm` | `queries/javascript/locals.scm` | `337756d2f632fa94461dbfddd73898568f46c43d` | by way of the grammar's file below |
| `jsdoc/highlights.scm` | `runtime/queries/jsdoc/highlights.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | modified in tree-sitter-grammars |
| `json/folds.scm` | `runtime/queries/json/folds.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | unchanged |
| `json/injections.scm` | `runtime/queries/json/injections.scm` | `9d47b2558b29fc8c0bce5f54b8424c5f8e2c80c7` | unchanged |
| `json/locals.scm` | `runtime/queries/json/locals.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | unchanged |
| `jsx/folds.scm` | `runtime/queries/jsx/folds.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | unchanged |
| `jsx/highlights.scm` | `runtime/queries/jsx/highlights.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | modified in tree-sitter-grammars |
| `jsx/indents.scm` | `runtime/queries/jsx/indents.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | unchanged |
| `jsx/injections.scm` | `runtime/queries/jsx/injections.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | unchanged |
| `kotlin/folds.scm` | `runtime/queries/kotlin/folds.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | unchanged |
| `kotlin/highlights.scm` | `queries/kotlin/highlights.scm` | `a2629ebcc0da7542f8723fb7f7b2e653ad230d3f` | by way of the grammar's file below |
| `kotlin/injections.scm` | `runtime/queries/kotlin/injections.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | modified in tree-sitter-grammars |
| `kotlin/locals.scm` | `runtime/queries/kotlin/locals.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | modified in tree-sitter-grammars |
| `latex/folds.scm` | `runtime/queries/latex/folds.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | unchanged |
| `latex/highlights.scm` | `runtime/queries/latex/highlights.scm` | `2c30e515ebe79037ab8d15f7e59c0e2690f50626` | modified in tree-sitter-grammars |
| `latex/injections.scm` | `runtime/queries/latex/injections.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | unchanged |
| `lua/folds.scm` | `runtime/queries/lua/folds.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | modified in tree-sitter-grammars |
| `lua/highlights.scm` | `queries/lua/highlights.scm` | `107e61afb7129d637ea6c3c68b97a22194b0bf16` | by way of the grammar's file below |
| `lua/indents.scm` | `runtime/queries/lua/indents.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | modified in tree-sitter-grammars |
| `lua/injections.scm` | `queries/lua/injections.scm` | `c80715f883b8c7963782973b23297c5dec7924be` | modified in tree-sitter-grammars |
| `make/folds.scm` | `runtime/queries/make/folds.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | modified in tree-sitter-grammars |
| `make/injections.scm` | `runtime/queries/make/injections.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | modified in tree-sitter-grammars |
| `markdown/folds.scm` | `runtime/queries/markdown/folds.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | modified in tree-sitter-grammars |
| `markdown/highlights.scm` | `runtime/queries/markdown/highlights.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | modified in tree-sitter-grammars |
| `markdown/indents.scm` | `runtime/queries/markdown/indents.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | unchanged |
| `markdown_inline/highlights.scm` | `runtime/queries/markdown_inline/highlights.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | modified in tree-sitter-grammars |
| `markdown_inline/injections.scm` | `runtime/queries/markdown_inline/injections.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | unchanged |
| `mermaid/injections.scm` | `runtime/queries/mermaid/injections.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | unchanged |
| `objc/folds.scm` | `runtime/queries/objc/folds.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | unchanged |
| `objc/highlights.scm` | `queries/objc/highlights.scm` | `dad1b7cd6606ffaa5c283ba73d707b4741a5f445` | by way of the grammar's file below |
| `objc/indents.scm` | `runtime/queries/objc/indents.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | unchanged |
| `objc/injections.scm` | `runtime/queries/objc/injections.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | modified in tree-sitter-grammars |
| `objc/locals.scm` | `runtime/queries/objc/locals.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | unchanged |
| `ocaml/folds.scm` | `runtime/queries/ocaml/folds.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | modified in tree-sitter-grammars |
| `ocaml/highlights.scm` | `queries/ocaml/highlights.scm` | `a6063b22c9e6d8660b82255d251c19d150725d9f` | by way of the grammar's file below |
| `ocaml/indents.scm` | `runtime/queries/ocaml/indents.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | modified in tree-sitter-grammars |
| `ocaml/injections.scm` | `runtime/queries/ocaml/injections.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | unchanged |
| `ocaml/locals.scm` | `queries/ocaml/locals.scm` | `7be8e6ca5c5dfe8414641c9d33605db31418debc` | by way of the grammar's file below |
| `pascal/folds.scm` | `runtime/queries/pascal/folds.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | modified in tree-sitter-grammars |
| `pascal/indents.scm` | `runtime/queries/pascal/indents.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | modified in tree-sitter-grammars |
| `pascal/injections.scm` | `runtime/queries/pascal/injections.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | modified in tree-sitter-grammars |
| `pascal/locals.scm` | `queries/pascal/locals.scm` | `5b90ea2abaa4303b9205b5c9002a8cdd0acd11a5` | by way of the grammar's file below |
| `perl/injections.scm` | `queries/perl/injections.scm` | `57a8acf0c4ed5e7f6dda83c3f9b073f8a99a70f9` | by way of the grammar's file below |
| `php/folds.scm` | `queries/php/folds.scm` | `3cb46f0c81a5640cd3b342e8a50e77058d7923d5` | modified in tree-sitter-grammars |
| `php/indents.scm` | `runtime/queries/php/indents.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | unchanged |
| `php_only/folds.scm` | `runtime/queries/php_only/folds.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | modified in tree-sitter-grammars |
| `php_only/indents.scm` | `runtime/queries/php_only/indents.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | unchanged |
| `proto/folds.scm` | `runtime/queries/proto/folds.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | modified in tree-sitter-grammars |
| `proto/highlights.scm` | `runtime/queries/proto/highlights.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | modified in tree-sitter-grammars |
| `proto/indents.scm` | `runtime/queries/proto/indents.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | unchanged |
| `proto/injections.scm` | `runtime/queries/proto/injections.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | unchanged |
| `python/folds.scm` | `runtime/queries/python/folds.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | modified in tree-sitter-grammars |
| `python/indents.scm` | `runtime/queries/python/indents.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | modified in tree-sitter-grammars |
| `python/injections.scm` | `runtime/queries/python/injections.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | modified in tree-sitter-grammars |
| `python/locals.scm` | `runtime/queries/python/locals.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | modified in tree-sitter-grammars |
| `regex/highlights.scm` | `runtime/queries/regex/highlights.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | unchanged |
| `ruby/folds.scm` | `runtime/queries/ruby/folds.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | modified in tree-sitter-grammars |
| `ruby/indents.scm` | `runtime/queries/ruby/indents.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | modified in tree-sitter-grammars |
| `ruby/injections.scm` | `runtime/queries/ruby/injections.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | modified in tree-sitter-grammars |
| `rust/folds.scm` | `runtime/queries/rust/folds.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | modified in tree-sitter-grammars |
| `rust/indents.scm` | `queries/rust/indents.scm` | `1b050206e490a4146cdf25c7b38969c1711b5620` | modified in tree-sitter-grammars |
| `rust/injections.scm` | `queries/rust/injections.scm` | `a4f4fcdd3ef1b36ebdad72741bbd85dd9ef5013e` | modified in tree-sitter-grammars |
| `rust/locals.scm` | `runtime/queries/rust/locals.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | modified in tree-sitter-grammars |
| `scala/folds.scm` | `runtime/queries/scala/folds.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | modified in tree-sitter-grammars |
| `scala/highlights.scm` | `runtime/queries/scala/highlights.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | modified in tree-sitter-grammars |
| `scala/injections.scm` | `runtime/queries/scala/injections.scm` | `024e6c5e46f8ec4237695b9e3020ecb601d817df` | unchanged |
| `scala/locals.scm` | `runtime/queries/scala/locals.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | modified in tree-sitter-grammars |
| `scheme/injections.scm` | `runtime/queries/scheme/injections.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | unchanged |
| `sql/folds.scm` | `runtime/queries/sql/folds.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | unchanged |
| `sql/highlights.scm` | `runtime/queries/sql/highlights.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | modified in tree-sitter-grammars |
| `sql/indents.scm` | `runtime/queries/sql/indents.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | unchanged |
| `sql/injections.scm` | `runtime/queries/sql/injections.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | modified in tree-sitter-grammars |
| `swift/folds.scm` | `runtime/queries/swift/folds.scm` | `13ddd4d7522ce3e5a1abc0ea34e10ec4e445908a` | modified in tree-sitter-grammars |
| `swift/highlights.scm` | `runtime/queries/swift/highlights.scm` | `13ddd4d7522ce3e5a1abc0ea34e10ec4e445908a` | by way of the grammar's file below |
| `swift/indents.scm` | `runtime/queries/swift/indents.scm` | `13ddd4d7522ce3e5a1abc0ea34e10ec4e445908a` | modified in tree-sitter-grammars |
| `swift/injections.scm` | `runtime/queries/swift/injections.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | unchanged |
| `swift/locals.scm` | `runtime/queries/swift/locals.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | modified in tree-sitter-grammars |
| `thrift/folds.scm` | `runtime/queries/thrift/folds.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | unchanged |
| `thrift/highlights.scm` | `runtime/queries/thrift/highlights.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | modified in tree-sitter-grammars |
| `thrift/indents.scm` | `runtime/queries/thrift/indents.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | modified in tree-sitter-grammars |
| `thrift/injections.scm` | `runtime/queries/thrift/injections.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | unchanged |
| `thrift/locals.scm` | `runtime/queries/thrift/locals.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | unchanged |
| `toml/folds.scm` | `runtime/queries/toml/folds.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | unchanged |
| `toml/highlights.scm` | `runtime/queries/toml/highlights.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | unchanged |
| `toml/injections.scm` | `runtime/queries/toml/injections.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | unchanged |
| `toml/locals.scm` | `runtime/queries/toml/locals.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | unchanged |
| `tsx/folds.scm` | `runtime/queries/tsx/folds.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | unchanged |
| `tsx/indents.scm` | `runtime/queries/tsx/indents.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | unchanged |
| `tsx/injections.scm` | `runtime/queries/tsx/injections.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | modified in tree-sitter-grammars |
| `tsx/locals.scm` | `runtime/queries/tsx/locals.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | unchanged |
| `typescript/folds.scm` | `runtime/queries/typescript/folds.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | unchanged |
| `typescript/indents.scm` | `runtime/queries/typescript/indents.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | unchanged |
| `typescript/locals.scm` | `queries/typescript/locals.scm` | `28bc7a070372c4ad6cbf3d98d4743b08defc0561` | by way of the grammar's file below |
| `xml/folds.scm` | `runtime/queries/xml/folds.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | unchanged |
| `xml/highlights.scm` | `runtime/queries/xml/highlights.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | modified in tree-sitter-grammars |
| `xml/indents.scm` | `queries/xml/indents.scm` | `5b3dd8cff1064db583ddd3edd314e94a02ea1bef` | modified in tree-sitter-grammars |
| `xml/injections.scm` | `runtime/queries/xml/injections.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | modified in tree-sitter-grammars |
| `xml/locals.scm` | `runtime/queries/xml/locals.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | unchanged |
| `yaml/folds.scm` | `runtime/queries/yaml/folds.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | unchanged |
| `yaml/indents.scm` | `runtime/queries/yaml/indents.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | unchanged |
| `yaml/injections.scm` | `runtime/queries/yaml/injections.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | modified in tree-sitter-grammars |
| `yaml/locals.scm` | `runtime/queries/yaml/locals.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | unchanged |
| `zig/folds.scm` | `runtime/queries/zig/folds.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | by way of the grammar's file below |
| `zig/highlights.scm` | `runtime/queries/zig/highlights.scm` | `77362027f7aa850c87419fd571151e76b0b342a6` | modified in tree-sitter-grammars |
| `zig/indents.scm` | `runtime/queries/zig/indents.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | modified in tree-sitter-grammars |
| `zig/injections.scm` | `runtime/queries/zig/injections.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | modified in tree-sitter-grammars |
| `zig/locals.scm` | `runtime/queries/zig/locals.scm` | `692b051b09935653befdb8f7ba8afdb640adf17b` | modified in tree-sitter-grammars |

### From a grammar's repository

These files come from the repository of a grammar listed under "Grammars" above, under the licence reproduced there: the licence and NOTICE files at every commit named are the ones reproduced there.

| File | Repository | Path | Commit | Licence | State |
| --- | --- | --- | --- | --- | --- |
| `ada/textobjects.scm` | tree-sitter-ada | `queries/textobjects.scm` | `ba7951a8f3fb08f9ea923625153e7670c89f30b4` | MIT | modified in tree-sitter-grammars |
| `bash/highlights.scm` | tree-sitter-bash | `queries/highlights.scm` | `422a07cb221b92c6b117e854efa8945a506b5214` | MIT | unchanged |
| `c-sharp/highlights.scm` | tree-sitter-c-sharp | `queries/highlights.scm` | `bf99ce8e40358bd215b06727b07ecc3f1e575afb` | MIT | unchanged |
| `c-sharp/tags.scm` | tree-sitter-c-sharp | `queries/tags.scm` | `bf99ce8e40358bd215b06727b07ecc3f1e575afb` | MIT | modified in tree-sitter-grammars |
| `c/highlights.scm` | tree-sitter-c | `queries/highlights.scm` | `70c0ddee618f4967c49143636c34982dd3375f89` | MIT | modified in tree-sitter-grammars |
| `c/tags.scm` | tree-sitter-c | `queries/tags.scm` | `0d33f0422ad391c6d652283645d546ffa048f503` | MIT | unchanged |
| `cpp/highlights.scm` | tree-sitter-c | `queries/highlights.scm` | `70c0ddee618f4967c49143636c34982dd3375f89` | MIT | modified in tree-sitter-grammars |
| `cpp/tags.scm` | tree-sitter-cpp | `queries/tags.scm` | `a71474021410973b29bfe99440d57bcd750246b1` | MIT | modified in tree-sitter-grammars |
| `css/highlights.scm` | tree-sitter-css | `queries/highlights.scm` | `5c89b88a37a2e1e36c031469462d6ee85ff2c13c` | MIT | unchanged |
| `dart/highlights.scm` | tree-sitter-dart | `queries/highlights.scm` | `590410cc679eca9955f7f3789e00ffa4d7c69d49` | MIT | modified in tree-sitter-grammars |
| `dart/tags.scm` | tree-sitter-dart | `queries/tags.scm` | `c2cc0993e67a61fad209728a128a9e25887459bc` | MIT | modified in tree-sitter-grammars |
| `go/highlights.scm` | tree-sitter-go | `queries/highlights.scm` | `174bc4405b312fde1c5d78468fccf0ad27e41617` | MIT | unchanged |
| `go/tags.scm` | tree-sitter-go | `queries/tags.scm` | `319e36193cdaf065ff4407f0a826b69d4eddc907` | MIT | modified in tree-sitter-grammars |
| `haskell/highlights.scm` | tree-sitter-haskell | `queries/highlights.scm` | `d9b04afe59cf6bcf76c43c48212ffae888eaeab4` | MIT | modified in tree-sitter-grammars |
| `haskell/injections.scm` | tree-sitter-haskell | `queries/injections.scm` | `50a04bf6d208a8f1aa90048c500fc4eb94b2df0f` | MIT | unchanged |
| `haskell/locals.scm` | tree-sitter-haskell | `queries/locals.scm` | `50a04bf6d208a8f1aa90048c500fc4eb94b2df0f` | MIT | unchanged |
| `java/highlights.scm` | tree-sitter-java | `queries/highlights.scm` | `04a649d1a0c40e53f946677463d7d8c4e8d6d0db` | MIT | unchanged |
| `java/tags.scm` | tree-sitter-java | `queries/tags.scm` | `4548c60eac1cecb2538bef5a1c4d0af2bfaa9eb4` | MIT | modified in tree-sitter-grammars |
| `javadoc/highlights.scm` | tree-sitter-javadoc | `queries/highlights.scm` | `4dba597e88b02c6e7cfb58cbcd5802a6ee58cf7f` | MIT | unchanged |
| `javascript/highlights.scm` | tree-sitter-javascript | `queries/highlights.scm` | `9802cc5812a19cd28168076af36e88b463dd3a18` | MIT | modified in tree-sitter-grammars |
| `javascript/injections.scm` | tree-sitter-javascript | `queries/injections.scm` | `1c751f8a4420f880b65b461bcf617ad2126ebc58` | MIT | modified in tree-sitter-grammars |
| `javascript/locals.scm` | tree-sitter-javascript | `queries/locals.scm` | `9802cc5812a19cd28168076af36e88b463dd3a18` | MIT | modified in tree-sitter-grammars |
| `javascript/tags.scm` | tree-sitter-javascript | `queries/tags.scm` | `f85369d14306244a62c1e1f11c26a3fdb972daad` | MIT | unchanged |
| `json/highlights.scm` | tree-sitter-json | `queries/highlights.scm` | `368736a6137770f785e1e7479a6be29417eb13aa` | MIT | unchanged |
| `kotlin/highlights.scm` | tree-sitter-kotlin | `queries/highlights.scm` | `e72b9d5acf709bf2f73561797a0107fb5370625a` | MIT | modified in tree-sitter-grammars |
| `lua/highlights.scm` | tree-sitter-lua | `queries/highlights.scm` | `d76023017f7485eae629cb60d406c7a1ca0f40c9` | MIT | unchanged |
| `lua/locals.scm` | tree-sitter-lua | `queries/locals.scm` | `f5e84ffc2b06858401e0d2edf5dce009efbe34b3` | MIT | unchanged |
| `lua/tags.scm` | tree-sitter-lua | `queries/tags.scm` | `54689a9876d4b249244036327eb10f34ed750bc6` | MIT | unchanged |
| `make/highlights.scm` | tree-sitter-make | `queries/highlights.scm` | `c8b7faa8b427785c7b6ca15ee324ed0ff7c7f1e8` | MIT | modified in tree-sitter-grammars |
| `markdown/injections.scm` | tree-sitter-markdown | `tree-sitter-markdown/queries/injections.scm` | `b7e263b722ce34fa6de983e1053b99b7a5ea6478` | MIT | modified in tree-sitter-grammars |
| `mermaid/highlights.scm` | tree-sitter-mermaid | `queries/highlights.scm` | `d1a99ef2c2907e33cd5d4c7ee62b75e4459dadbc` | MIT | unchanged |
| `objc/highlights.scm` | tree-sitter-objc | `queries/highlights.scm` | `a360943e0f108b7d0935924a4eb772ce1a6aaec7` | MIT | unchanged |
| `ocaml/highlights.scm` | tree-sitter-ocaml | `queries/highlights.scm` | `45ddc92d18fa11b2ca1a18cd94de4e63feea0806` | MIT | unchanged |
| `ocaml/locals.scm` | tree-sitter-ocaml | `queries/locals.scm` | `e0e760fe206e5a860687dd5f14e6911c515e5c70` | MIT | unchanged |
| `ocaml/tags.scm` | tree-sitter-ocaml | `queries/tags.scm` | `f9fea5ffc334fc2148085e74ace008af244695b1` | MIT | unchanged |
| `pascal/highlights.scm` | tree-sitter-pascal | `queries/highlights.scm` | `d0ebabefaea9ac3f6fc3004cf08cd121b66da9e4` | MIT | unchanged |
| `pascal/locals.scm` | tree-sitter-pascal | `queries/locals.scm` | `22fb8f8fe5e6822266e82794a1d19444f9f3879e` | MIT | unchanged |
| `perl/folds.scm` | tree-sitter-perl | `queries/folds.scm` | `bfb130c6f954b69ac71796892cf340891d670b7a` | MIT | modified in tree-sitter-grammars |
| `perl/highlights.scm` | tree-sitter-perl | `queries/highlights.scm` | `bfb130c6f954b69ac71796892cf340891d670b7a` | MIT | modified in tree-sitter-grammars |
| `perl/injections.scm` | tree-sitter-perl | `queries/injections.scm` | `bfb130c6f954b69ac71796892cf340891d670b7a` | MIT | unchanged |
| `php/highlights.scm` | tree-sitter-php | `queries/highlights.scm` | `43fbdd53c34a82d9a27c83f9798a2918b3dcd270` | MIT | unchanged |
| `php/injections.scm` | tree-sitter-php | `queries/injections.scm` | `ad1c8c837e34222839c804bf96466e518787e180` | MIT | modified in tree-sitter-grammars |
| `php/tags.scm` | tree-sitter-php | `queries/tags.scm` | `cb4fac2ee6c34b5e32f98a3ad3e7c17f5288cc85` | MIT | unchanged |
| `python/highlights.scm` | tree-sitter-python | `queries/highlights.scm` | `1124c1872b6cc499b1a8848c366e07da156b505a` | MIT | unchanged |
| `ruby/highlights.scm` | tree-sitter-ruby | `queries/highlights.scm` | `d60f2a5a68e1b41ba51caa6d3d21593a810c01d6` | MIT | unchanged |
| `ruby/locals.scm` | tree-sitter-ruby | `queries/locals.scm` | `6ad22db67f131eb01adf1a98d2e22c6d3a689a13` | MIT | unchanged |
| `ruby/tags.scm` | tree-sitter-ruby | `queries/tags.scm` | `49c5f6e9cc9ea1a3b9fb5414ba0c2d697acb2448` | MIT | unchanged |
| `rust/highlights.scm` | tree-sitter-rust | `queries/highlights.scm` | `5274df6aa92d9016edf566aeff4d77206184dfaa` | MIT | unchanged |
| `rust/tags.scm` | tree-sitter-rust | `queries/tags.scm` | `1f63b33efee17e833e0ea29266dd3d713e27e321` | MIT | unchanged |
| `scala/tags.scm` | tree-sitter-scala | `queries/tags.scm` | `b6a91556ef76f1f903eebb8c8a4dbac1f52cced2` | MIT | modified in tree-sitter-grammars |
| `scheme/highlights.scm` | tree-sitter-scheme | `queries/highlights.scm` | `184e7596ee0cbaef79230cae1b4ee5bb4fbad314` | MIT | unchanged |
| `swift/highlights.scm` | tree-sitter-swift | `queries/highlights.scm` | `c79af47572af041d5df15e9d805cf575bb0265e0` | MIT | unchanged |
| `swift/textobjects.scm` | tree-sitter-swift | `queries/textobjects.scm` | `f1a48a33a7ceaf8817f7a340ea4ef1b549ffa176` | MIT | modified in tree-sitter-grammars |
| `tsx/highlights.scm` | tree-sitter-javascript | `queries/highlights-jsx.scm` | `9802cc5812a19cd28168076af36e88b463dd3a18` | MIT | modified in tree-sitter-grammars |
| `tsx/tags.scm` | tree-sitter-javascript | `queries/tags.scm` | `687e20a18ea2a003482aacb44d8ede5511cc95f7` | MIT | modified in tree-sitter-grammars |
| `typescript/highlights.scm` | tree-sitter-javascript | `queries/highlights.scm` | `9802cc5812a19cd28168076af36e88b463dd3a18` | MIT | modified in tree-sitter-grammars |
| `typescript/injections.scm` | tree-sitter-javascript | `queries/injections.scm` | `1c751f8a4420f880b65b461bcf617ad2126ebc58` | MIT | modified in tree-sitter-grammars |
| `typescript/locals.scm` | tree-sitter-javascript | `queries/locals.scm` | `9802cc5812a19cd28168076af36e88b463dd3a18` | MIT | modified in tree-sitter-grammars |
| `typescript/tags.scm` | tree-sitter-javascript | `queries/tags.scm` | `f85369d14306244a62c1e1f11c26a3fdb972daad` | MIT | modified in tree-sitter-grammars |
| `yaml/highlights.scm` | tree-sitter-yaml | `queries/highlights.scm` | `af011e6e1a448c1080b8281203436fe2ed27b101` | MIT | unchanged |
| `zig/folds.scm` | tree-sitter-zig | `queries/folds.scm` | `b3d906d56ab4c5839581deae3a1ca7d83c38e756` | MIT | modified in tree-sitter-grammars |

### Written in tree-sitter-grammars

These files are covered by the licence of tree-sitter-grammars, reproduced below.

- `ada/indents.scm`
- `ada/tags.scm`
- `bash/tags.scm`
- `c-sharp/indents.scm`
- `commonlisp/folds.scm`
- `commonlisp/indents.scm`
- `commonlisp/tags.scm`
- `css/tags.scm`
- `dtd/indents.scm`
- `dtd/tags.scm`
- `haskell/folds.scm`
- `haskell/indents.scm`
- `haskell/tags.scm`
- `html/tags.scm`
- `idl/tags.scm`
- `json/indents.scm`
- `kotlin/indents.scm`
- `kotlin/tags.scm`
- `make/indents.scm`
- `make/locals.scm`
- `make/tags.scm`
- `markdown/tags.scm`
- `mermaid/folds.scm`
- `mermaid/indents.scm`
- `mermaid/locals.scm`
- `objc/tags.scm`
- `pascal/tags.scm`
- `perl/indents.scm`
- `perl/locals.scm`
- `perl/tags.scm`
- `php/locals.scm`
- `proto/locals.scm`
- `proto/tags.scm`
- `python/tags.scm`
- `scala/indents.scm`
- `scheme/folds.scm`
- `scheme/indents.scm`
- `scheme/locals.scm`
- `scheme/tags.scm`
- `sql/locals.scm`
- `sql/tags.scm`
- `swift/tags.scm`
- `thrift/tags.scm`
- `toml/indents.scm`
- `toml/tags.scm`
- `xml/tags.scm`
- `yaml/tags.scm`
- `zig/tags.scm`

## tree-sitter-grammars

The query files written in tree-sitter-grammars, and the changes it made to the others, are covered by its own licence.

### LICENSE

```text
MIT License

Copyright (c) 2025-2026 Tony Kinnis

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

--------------------------------------------------------------------------------

This licence covers the work of this repository itself. The tree-sitter
runtime, each grammar, and the query files that come from nvim-treesitter or
from a grammar's own repository are covered by their own licences, which
THIRD_PARTY_NOTICES.md reproduces in full.
```

## Apache License 2.0

The licence of nvim-treesitter, from which the query files listed under "Derived from nvim-treesitter" come.

```text
                                 Apache License
                           Version 2.0, January 2004
                        http://www.apache.org/licenses/

   TERMS AND CONDITIONS FOR USE, REPRODUCTION, AND DISTRIBUTION

   1. Definitions.

      "License" shall mean the terms and conditions for use, reproduction,
      and distribution as defined by Sections 1 through 9 of this document.

      "Licensor" shall mean the copyright owner or entity authorized by
      the copyright owner that is granting the License.

      "Legal Entity" shall mean the union of the acting entity and all
      other entities that control, are controlled by, or are under common
      control with that entity. For the purposes of this definition,
      "control" means (i) the power, direct or indirect, to cause the
      direction or management of such entity, whether by contract or
      otherwise, or (ii) ownership of fifty percent (50%) or more of the
      outstanding shares, or (iii) beneficial ownership of such entity.

      "You" (or "Your") shall mean an individual or Legal Entity
      exercising permissions granted by this License.

      "Source" form shall mean the preferred form for making modifications,
      including but not limited to software source code, documentation
      source, and configuration files.

      "Object" form shall mean any form resulting from mechanical
      transformation or translation of a Source form, including but
      not limited to compiled object code, generated documentation,
      and conversions to other media types.

      "Work" shall mean the work of authorship, whether in Source or
      Object form, made available under the License, as indicated by a
      copyright notice that is included in or attached to the work
      (an example is provided in the Appendix below).

      "Derivative Works" shall mean any work, whether in Source or Object
      form, that is based on (or derived from) the Work and for which the
      editorial revisions, annotations, elaborations, or other modifications
      represent, as a whole, an original work of authorship. For the purposes
      of this License, Derivative Works shall not include works that remain
      separable from, or merely link (or bind by name) to the interfaces of,
      the Work and Derivative Works thereof.

      "Contribution" shall mean any work of authorship, including
      the original version of the Work and any modifications or additions
      to that Work or Derivative Works thereof, that is intentionally
      submitted to Licensor for inclusion in the Work by the copyright owner
      or by an individual or Legal Entity authorized to submit on behalf of
      the copyright owner. For the purposes of this definition, "submitted"
      means any form of electronic, verbal, or written communication sent
      to the Licensor or its representatives, including but not limited to
      communication on electronic mailing lists, source code control systems,
      and issue tracking systems that are managed by, or on behalf of, the
      Licensor for the purpose of discussing and improving the Work, but
      excluding communication that is conspicuously marked or otherwise
      designated in writing by the copyright owner as "Not a Contribution."

      "Contributor" shall mean Licensor and any individual or Legal Entity
      on behalf of whom a Contribution has been received by Licensor and
      subsequently incorporated within the Work.

   2. Grant of Copyright License. Subject to the terms and conditions of
      this License, each Contributor hereby grants to You a perpetual,
      worldwide, non-exclusive, no-charge, royalty-free, irrevocable
      copyright license to reproduce, prepare Derivative Works of,
      publicly display, publicly perform, sublicense, and distribute the
      Work and such Derivative Works in Source or Object form.

   3. Grant of Patent License. Subject to the terms and conditions of
      this License, each Contributor hereby grants to You a perpetual,
      worldwide, non-exclusive, no-charge, royalty-free, irrevocable
      (except as stated in this section) patent license to make, have made,
      use, offer to sell, sell, import, and otherwise transfer the Work,
      where such license applies only to those patent claims licensable
      by such Contributor that are necessarily infringed by their
      Contribution(s) alone or by combination of their Contribution(s)
      with the Work to which such Contribution(s) was submitted. If You
      institute patent litigation against any entity (including a
      cross-claim or counterclaim in a lawsuit) alleging that the Work
      or a Contribution incorporated within the Work constitutes direct
      or contributory patent infringement, then any patent licenses
      granted to You under this License for that Work shall terminate
      as of the date such litigation is filed.

   4. Redistribution. You may reproduce and distribute copies of the
      Work or Derivative Works thereof in any medium, with or without
      modifications, and in Source or Object form, provided that You
      meet the following conditions:

      (a) You must give any other recipients of the Work or
          Derivative Works a copy of this License; and

      (b) You must cause any modified files to carry prominent notices
          stating that You changed the files; and

      (c) You must retain, in the Source form of any Derivative Works
          that You distribute, all copyright, patent, trademark, and
          attribution notices from the Source form of the Work,
          excluding those notices that do not pertain to any part of
          the Derivative Works; and

      (d) If the Work includes a "NOTICE" text file as part of its
          distribution, then any Derivative Works that You distribute must
          include a readable copy of the attribution notices contained
          within such NOTICE file, excluding those notices that do not
          pertain to any part of the Derivative Works, in at least one
          of the following places: within a NOTICE text file distributed
          as part of the Derivative Works; within the Source form or
          documentation, if provided along with the Derivative Works; or,
          within a display generated by the Derivative Works, if and
          wherever such third-party notices normally appear. The contents
          of the NOTICE file are for informational purposes only and
          do not modify the License. You may add Your own attribution
          notices within Derivative Works that You distribute, alongside
          or as an addendum to the NOTICE text from the Work, provided
          that such additional attribution notices cannot be construed
          as modifying the License.

      You may add Your own copyright statement to Your modifications and
      may provide additional or different license terms and conditions
      for use, reproduction, or distribution of Your modifications, or
      for any such Derivative Works as a whole, provided Your use,
      reproduction, and distribution of the Work otherwise complies with
      the conditions stated in this License.

   5. Submission of Contributions. Unless You explicitly state otherwise,
      any Contribution intentionally submitted for inclusion in the Work
      by You to the Licensor shall be under the terms and conditions of
      this License, without any additional terms or conditions.
      Notwithstanding the above, nothing herein shall supersede or modify
      the terms of any separate license agreement you may have executed
      with Licensor regarding such Contributions.

   6. Trademarks. This License does not grant permission to use the trade
      names, trademarks, service marks, or product names of the Licensor,
      except as required for reasonable and customary use in describing the
      origin of the Work and reproducing the content of the NOTICE file.

   7. Disclaimer of Warranty. Unless required by applicable law or
      agreed to in writing, Licensor provides the Work (and each
      Contributor provides its Contributions) on an "AS IS" BASIS,
      WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
      implied, including, without limitation, any warranties or conditions
      of TITLE, NON-INFRINGEMENT, MERCHANTABILITY, or FITNESS FOR A
      PARTICULAR PURPOSE. You are solely responsible for determining the
      appropriateness of using or redistributing the Work and assume any
      risks associated with Your exercise of permissions under this License.

   8. Limitation of Liability. In no event and under no legal theory,
      whether in tort (including negligence), contract, or otherwise,
      unless required by applicable law (such as deliberate and grossly
      negligent acts) or agreed to in writing, shall any Contributor be
      liable to You for damages, including any direct, indirect, special,
      incidental, or consequential damages of any character arising as a
      result of this License or out of the use or inability to use the
      Work (including but not limited to damages for loss of goodwill,
      work stoppage, computer failure or malfunction, or any and all
      other commercial damages or losses), even if such Contributor
      has been advised of the possibility of such damages.

   9. Accepting Warranty or Additional Liability. While redistributing
      the Work or Derivative Works thereof, You may choose to offer,
      and charge a fee for, acceptance of support, warranty, indemnity,
      or other liability obligations and/or rights consistent with this
      License. However, in accepting such obligations, You may act only
      on Your own behalf and on Your sole responsibility, not on behalf
      of any other Contributor, and only if You agree to indemnify,
      defend, and hold each Contributor harmless for any liability
      incurred by, or claims asserted against, such Contributor by reason
      of your accepting any such warranty or additional liability.

   END OF TERMS AND CONDITIONS

   APPENDIX: How to apply the Apache License to your work.

      To apply the Apache License to your work, attach the following
      boilerplate notice, with the fields enclosed by brackets "[]"
      replaced with your own identifying information. (Don't include
      the brackets!)  The text should be enclosed in the appropriate
      comment syntax for the file format. We also recommend that a
      file or class name and description of purpose be included on the
      same "printed page" as the copyright notice for easier
      identification within third-party archives.

   Copyright [yyyy] [name of copyright owner]

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
```

