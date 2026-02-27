# Security Guidelines

## OWASP Top 10 Awareness

- **Input validation**: Validate and sanitize all user inputs
- **SQL injection**: Use parameterized queries, never concatenate SQL
- **XSS prevention**: Escape user content, use CSP headers
- **Authentication**: Use established libraries (e.g., passport, PyJWT)
- **Authorization**: Check permissions before every sensitive operation
- **Secrets management**: Never commit secrets, use environment variables or secret managers
- **Dependency scanning**: Keep dependencies updated, review security advisories

## Secure Coding Practices

- **Principle of least privilege**: Grant minimum necessary permissions
- **Defense in depth**: Multiple layers of security controls
- **Fail securely**: Default to denying access on errors
- **Audit logging**: Log security-relevant events
- **Crypto**: Use established libraries (libsodium, cryptography.py), never roll your own

## Common Vulnerabilities to Avoid

- **Command injection**: Validate inputs, use parameterized APIs
- **Path traversal**: Validate file paths, use safe path joining
- **Insecure deserialization**: Validate serialized data, use safe formats
- **CSRF**: Use CSRF tokens for state-changing operations
- **Open redirects**: Validate redirect URLs against allowlist
