# Authenticode Signing Setup Guide

This guide covers the setup required to enable Authenticode signing for the Cutline DNS Windows installer using Azure Artifact Signing.

## Overview

Two workflows have been added:

1. **`sign-windows-installer.yml`** - Standalone workflow to sign existing release assets on demand
2. **`build-windows-installer.yml`** - Updated to include optional signing after build

Both workflows use GitHub OIDC authentication with Azure and the Azure Artifact Signing service.

## Prerequisites

### Azure Setup

1. **Azure Artifact Signing Account**: `cutlinesign`
2. **Certificate Profile**: `cutline`
3. **Code Signing Endpoint**: `https://eus.codesigning.azure.net/`
4. **Timestamp Server**: `http://timestamp.acs.microsoft.com`

### GitHub Environment

Create a GitHub environment named **`cutline-sign`** in the repository settings:

1. Go to Settings → Environments → New environment
2. Name: `cutline-sign`
3. Add environment secrets (see below)

### Azure Federated Credential

Configure Azure AD application with GitHub federated credential:

- **Entity type**: Environment
- **Environment name**: `cutline-sign`
- **Repository**: `dov-max/narge-spec`

This allows GitHub Actions running in the `cutline-sign` environment to authenticate to Azure without storing long-lived credentials.

## Required GitHub Secrets

Configure these secrets in the **`cutline-sign`** environment:

| Secret Name | Description | Example |
|------------|-------------|---------|
| `AZURE_CLIENT_ID` | Azure application (client) ID | `00000000-0000-0000-0000-000000000000` |
| `AZURE_TENANT_ID` | Azure tenant (directory) ID | `00000000-0000-0000-0000-000000000000` |
| `AZURE_SUBSCRIPTION_ID` | Azure subscription ID | `00000000-0000-0000-0000-000000000000` |
| `AZURE_CLIENT_SECRET` | Azure client secret | (required by artifact-signing-action) |

### How to Configure

1. Go to repository Settings → Environments → `cutline-sign`
2. Click "Add secret" for each secret above
3. Enter the name and value from your Azure setup
4. Click "Add secret"

## Usage

### Automatic Signing (Build Workflow)

Once secrets are configured, new builds on the `main` branch will automatically be signed:

```bash
# Push to main branch
git push origin main
```

The workflow will:
1. Build the installer
2. Sign it with Azure Artifact Signing (if secrets exist)
3. Verify the signature
4. Upload to GitHub Release

### Manual Signing (Existing Release)

To sign an existing release asset:

1. Go to Actions → "Sign Windows Installer with Authenticode"
2. Click "Run workflow"
3. Configure inputs:
   - **Release tag**: `cutline-dns-v1.1.0` (or other release)
   - **Asset name**: `cutline-dns-setup.exe`
4. Click "Run workflow"

The workflow will download the exe, sign it, verify the signature, and upload it back to the release.

### Sign the Current v1.1.0 Release

To sign the existing `cutline-dns-v1.1.0` release immediately:

1. Ensure secrets are configured in the `cutline-sign` environment
2. Go to Actions → "Sign Windows Installer with Authenticode" → Run workflow
3. Use defaults (already set to v1.1.0 and cutline-dns-setup.exe)
4. Click "Run workflow"

## Verification

### In GitHub Actions

The workflow will show signature verification in the logs:

```
Signature status: Valid
✓ Authenticode signature is valid!
  Subject: CN=Your Organization
  Issuer: CN=Certificate Authority
  Thumbprint: ABC123...
  Valid from: 2024-01-01 00:00:00
  Valid to: 2027-01-01 00:00:00
  Time stamper: CN=Microsoft Time Stamp Service
```

### On Windows

Users can verify the signature:

1. Download the signed exe
2. Right-click → Properties → Digital Signatures tab
3. Select the signature → Details
4. Should show "This digital signature is OK"

### SmartScreen

Windows SmartScreen will recognize the signed exe and show the publisher name instead of "Unknown publisher" when users run it.

## Backward Compatibility

The build workflow remains compatible with PRs and environments without signing secrets:

- **With secrets**: Exe is signed and verified
- **Without secrets**: Exe is built unsigned (skips signing steps)

This ensures CI continues to work for contributors without access to signing credentials.

## Troubleshooting

### "Signature status: NotSigned"

- Check that Azure secrets are correctly configured
- Verify the Azure federated credential is set up for the `cutline-sign` environment
- Check Azure Artifact Signing account permissions

### "Failed to authenticate to Azure"

- Verify `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, and `AZURE_SUBSCRIPTION_ID` are correct
- Check that the GitHub environment name matches the federated credential (`cutline-sign`)
- Ensure the Azure federated credential is configured for entity type "Environment"

### "Certificate profile not found"

- Verify the certificate profile name is exactly `cutline`
- Check that the profile exists in the `cutlinesign` account
- Verify account permissions in Azure

## Security Notes

- Secrets are stored in GitHub environment secrets (encrypted)
- OIDC tokens are short-lived and scoped to the workflow run
- Signed exe is uploaded to release (not committed to git)
- The 67MB exe file should never be committed to the repository

## References

- [Azure Artifact Signing Documentation](https://learn.microsoft.com/azure/security/code-signing/)
- [GitHub OIDC with Azure](https://docs.github.com/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-azure)
- [azure/artifact-signing-action](https://github.com/azure/artifact-signing-action)
