# Export Compliance

Apps that use encryption beyond what the operating system provides, or that implement their own cryptography, may need documentation. Apple asks about this on every upload.

- Uses only HTTPS/TLS and OS-provided encryption: set ITSAppUsesNonExemptEncryption to NO in the app's Info.plist.
- Uses custom or non-standard encryption: set it to YES and follow Apple's export compliance questions.

**Your determination:** NO. The app uses only HTTPS via URLSession to api.scryfall.com and OS-provided facilities. It has no custom cryptography and no third-party crypto libraries. `ITSAppUsesNonExemptEncryption` is set to `false` in `project.yml`.