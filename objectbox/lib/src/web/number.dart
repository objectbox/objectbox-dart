@JS('objectbox')
library number;

import "package:js/js.dart";

/// Multiplies a value by 2. (Also a full example of TypeDoc's functionality.)
/// ### Example (es module)
/// ```js
/// import { double } from 'typescript-starter'
/// console.log(double(4))
/// // => 8
/// ```
/// ### Example (commonjs)
/// ```js
/// var double = require('typescript-starter').double;
/// console.log(double(4))
/// // => 8
/// ```
/// @anotherNote Some other value.
@JS()
external num Function(num) get double;

/// Raise the value of the first parameter to the power of the second using the
/// es7 exponentiation operator (`**`).
/// ### Example (es module)
/// ```js
/// import { power } from 'typescript-starter'
/// console.log(power(2,3))
/// // => 8
/// ```
/// ### Example (commonjs)
/// ```js
/// var power = require('typescript-starter').power;
/// console.log(power(2,3))
/// // => 8
/// ```
@JS()
external num Function(num, num) get power;

/// Multiply a value by 2 (dart code)
num double2(num v) => v * 2;
