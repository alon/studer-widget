'use strict';


function str__a_minus_b(a, b)
{
    for (var i = Math.min(a.length, b.length) - 1; i >= 0 ; --i)
    {
        if (a[i] != b[i])
        {
            return a.substring(0, i + 1);
        }
    }
    return '';
}

export { str__a_minus_b };
