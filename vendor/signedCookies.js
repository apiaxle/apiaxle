var crypto = require('crypto'),
    pattern = new RegExp(/^(?:([0-9a-f]+):)?(.*)$/);

var signedCookies = module.exports.init = function(secret, digest)
{
    return new SignedCookieParser(secret, digest || 'sha1');
};

var SignedCookieParser = function(secret, digest)
{
    this.secret = secret;
    this.digest = digest;
};

SignedCookieParser.prototype._get_digest = function(key, value)
{
    var hmac = crypto.createHmac(this.digest, this.secret);
    hmac.update(key+':'+value);
    
    return hmac.digest('hex');
};

SignedCookieParser.prototype.decode = function()
{
    var t = this;
    
    function unsign(key, signed_value)
    {
        var matches = pattern.exec(signed_value);
        
        if(matches && matches.length === 3)
        {
            var signature = matches[1],
                unsigned_value = matches[2];
                
            if(signature === t._get_digest(key, unsigned_value))
            {
                return unsigned_value;
            }
        }

        return false;
    }
    
    return function decode(req, res, next) {
        if(!req.cookies) throw new Error('You must use `express.parseCookies()` middleware first!');

        for(var morsel in req.cookies)
        {
            var decoded = unsign(morsel, req.cookies[morsel]);
            if(false === decoded){
                // cookie is not signed properly or has been tampered with
                delete req.cookies[morsel];
            }
            else
            {
                req.cookies[morsel] = decoded;
            }
        }
        next();
    }
};

SignedCookieParser.prototype.encode = function()
{
    var t = this;
    
    function sign(key, val)
    {
        return t._get_digest(key, val) + ':' + val;
    }
    
    return function encode(req, res, next)
    {
        if('function' === typeof res.signedCookie) return next();
        
        res.signedCookie = function signedCookie(key, val, options)
        {
            res.cookie(key, sign(key, val), options);
        };
        
        next();
    }
};