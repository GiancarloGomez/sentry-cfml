# Sentry SDK for ColdFusion

sentry-cfml is based on the original raven-cfml client developed
by jmacul2 (https://github.com/jmacul2/raven-cfml)

sentry-cfml is a CFML client for [Sentry](<https://sentry.io/welcome/>) and it has
been updated to work with Sentry's Protocol @ version 7.

sentry-cfml been updated to full script with support to instantiate
and use as a singleton. Also some functions have been rewritten to use either
new ColdFusion language enhancements or existing functions.

sentry-cfml is for use with ColdFusion 2016 testing on earlier
versions of ColdFusion has not been done.

Sentry SDK Documentation
https://docs.sentry.io/clientdev/

## Installation
To install simply clone or download the sentry.cfc file and place it anywhere in your
project.

## Instantiating as a Singleton
sentry-cfml can be instantiated each time you call it or it can
also live as a Singleton in your Application scope.

```javascript
function onApplicationStart(){

    application.sentry = new path.to.sentry(
        release     : "release-number-of-your-application",
        environment : "production|staging|etc",
        publicKey   : "your-public-key",
        privateKey  : "your-private-key",
        projectID   : "your-project-id",
        customPost   : function ({ url, method }, authHeader, jsonCapture) {}
    );

    return true;
}
```

## Using in your Application
Add to the onError() function to use for application wide errors.
 ```javascript
function onError(
    exception,
    eventName
){
    application.sentry.captureException(
        exception : arguments.exception
    );
}
```

## Usage
It is recommended that you review the [Sentry SDK Docs](https://docs.sentry.io/clientdev/attributes/) to understand the attributes and Interfaces that are supported.

## Examples
The following are examples on how to send messages and errors to Sentry. The examples are based on the singleton instance.

### Passing Messages
An information Message using a thread to post to Sentry
including data that is passed into the [User Interface](https://docs.sentry.io/clientdev/interfaces/user/)
```javascript

    application.sentry.captureMessage(
        message     : "This is just info",
        level       : "info",
        useThread   : true,
        userInfo    : {
            id          : 100,
            email       : "john.doe@test.com",
            type        : "administrator",
            username    : "john",
            ip_address  : cgi.remote_addr
        }
    );

```

Other level types allowed by Sentry
```javascript

    application.sentry.captureMessage(
        message :"This is a fatal message",
        level   :"fatal"
    );

    application.sentry.captureMessage(
        message :"This is an error message",
        level   :"error"
    );

    application.sentry.captureMessage(
        message :"This is a warning message",
        level   :"warning"
    );


    application.sentry.captureMessage(
        message :"This is a debug message",
        level   :"debug"
    );

```

### Capturing Errors
To capture an error you simply use the ``captureExeption`` function. Capturing an exception allows
for more options than just posting a message. Review the argument hints on the CFC for more information.
```javascript

    application.sentry.captureException(
        exception                   : e,
        level                       : "error",
        oneLineStackTrace           : true,
        showJavaStackTrace          : true,
        removeTabsOnJavaStackTrace  : false,
        additionalData              : {
            session : session
        },
        useSignature                : false,
        cgiVars                     : cgi,
        useThread                   : true,
        userInfo                    : {}
    );

```


