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


function build_object(keys, key_to_value)
{
    let ret = {}
    for (let i = 0 ; i < keys.length ; ++i) {
        let k = keys[i];
        ret[k] = key_to_value(k);
    }
    return ret;
}


export { str__a_minus_b, build_object };
