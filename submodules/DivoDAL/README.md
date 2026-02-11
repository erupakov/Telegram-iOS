# DivoDAL — Developer Guide

DivoDAL is the Data Access Layer for the Divo REST API. It provides a typed Swift API over `https://backend.divo.fashion/api`, with DAOs per domain and a shared HTTP client.

## Overview

- **APIClient**: single HTTP client (base URL, Bearer auth, JSON/multipart, error mapping).
- **DAOs**: one class per API domain (Auth, User, Publication, etc.), each exposing `async throws` methods that map 1:1 to API paths.
- **Models**: request/response DTOs where the API contract is known (e.g. `LoginRequest`, `LoginResponse`, `UserInfo`); other endpoints return raw `Data` for you to decode.

All network calls use Swift concurrency (`async throws`). Authentication is optional and supplied via a closure so you can refresh or change the token without recreating the client.

## Adding the dependency

In your `BUILD` file, add DivoDAL to `deps`:

```python
deps = [
    "//submodules/DivoDAL:DivoDAL",
    # ...
],
```

Then import in Swift:

```swift
import DivoDAL
```

## Configuration

### Creating the client

Use the default base URL and no auth for unauthenticated calls:

```swift
let client = APIClient()
```

For authenticated calls, pass a closure that returns the current token (e.g. from your auth store):

```swift
let client = APIClient(authToken: { keychain.accessToken })
```

Custom base URL or `URLSession`:

```swift
let client = APIClient(
    baseURL: URL(string: "https://staging.backend.divo.fashion")!,
    session: myURLSession,
    authToken: { myToken }
)
```

The client always prefixes paths with `/api` (e.g. `/auth/login` → `https://backend.divo.fashion/api/auth/login`).

### Token handling

- **No token**: use `APIClient()` or `authToken: { nil }` for endpoints that don’t require auth (login, registration, some dictionary/geo, etc.).
- **With token**: use `authToken: { ... }` so the client adds `Authorization: Bearer <token>` to every request. The closure is called per request, so you can return an updated token after refresh.
- **Override per call**: DAO methods use the client’s token by default; the low-level `request`/`requestRaw`/`requestJSON` support an optional `tokenOverride` if you need a different token for a single request.

Token storage and refresh are **not** implemented in DivoDAL; the app is responsible for persisting and providing the token.

## Usage examples

### Authentication

```swift
let client = APIClient()
let authDAO = AuthDAO(client: client)

// Email/password login (no auth required)
let response = try await authDAO.login(
    email: "user@example.com",
    password: "secret",
    deviceId: UIDevice.current.identifierForVendor?.uuidString ?? "",
    deviceType: "ios"
)
let accessToken = response.accessToken
// Persist accessToken and use it when creating an authenticated client

// Logout (requires auth)
let authenticatedClient = APIClient(authToken: { accessToken })
let authDAOWithAuth = AuthDAO(client: authenticatedClient)
try await authDAOWithAuth.logout()
```

### Registration and email confirmation

```swift
try await authDAO.registration(
    email: "new@example.com",
    password: "secret",
    timezone: TimeZone.current.identifier,
    role: "model"
)

try await authDAO.sendEmailCode(email: "new@example.com", type: "confirm_email")
// User receives code; then:
let loginResponse = try await authDAO.confirmEmail(
    code: 123456,
    token: tokenFromSendEmailCode,
    deviceId: deviceId,
    deviceType: "ios"
)
```

### Current user and user by ID

```swift
let userDAO = UserDAO(client: authenticatedClient)

let me: UserInfo = try await userDAO.info()
let other: UserInfo = try await userDAO.user(id: 42)
```

### Endpoints that return raw JSON

Many endpoints have unspecified response schemas and return `Data`. Decode with `JSONDecoder` or `JSONSerialization`:

```swift
let data = try await userDAO.rating()
let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

// Or with a custom Codable type when you know the shape:
struct RatingResponse: Codable { let score: Double }
let rating = try JSONDecoder().decode(RatingResponse.self, from: data)
```

### Sending a JSON body (generic)

Methods that take `body: [String: Any]?` send it as `application/json`:

```swift
try await userDAO.updateProfile(body: [
    "firstName": "Jane",
    "lastName": "Doe"
])
```

### File upload (multipart)

Use `FileDAO` or `UserGalleryDAO` with `MultipartForm`:

```swift
let fileDAO = FileDAO(client: client)
var form = MultipartForm()
form.append(name: "file", data: imageData, filename: "photo.jpg", mimeType: "image/jpeg")
let responseData = try await fileDAO.uploadFile(multipart: form)
```

### Query parameters

For GET endpoints with query params (e.g. Geo, File resize), the DAO methods accept parameters that are turned into query strings:

```swift
let geoDAO = GeoDAO(client: client)
let data = try await geoDAO.searchByAddressName(q: "Paris")

let fileDAO = FileDAO(client: client)
let resized = try await fileDAO.resize(url: imageURL, width: 200, height: 200)
```

## Error handling

All DAO methods throw on failure. Use `DivoAPIError` to distinguish cases:

```swift
do {
    let response = try await authDAO.login(...)
} catch DivoAPIError.unauthorized {
    // 401 — invalid or missing token
} catch DivoAPIError.forbidden {
    // 403 — not allowed
} catch DivoAPIError.validation(let message, let errors) {
    // 422 — validation failed; message and field errors
} catch DivoAPIError.serverError(let statusCode) {
    // Other non-2xx
} catch DivoAPIError.decoding(let error) {
    // Response body could not be decoded to the expected type
} catch DivoAPIError.network(let error) {
    // Network failure (e.g. no connection)
}
```

`DivoAPIErrorPayload` is used internally to parse 422 bodies; you can use it to inspect `message` and `errors` when you catch `.validation`.

## DAO reference

| DAO | Domain | Main operations |
|-----|--------|-----------------|
| **AuthDAO** | Auth | login, logout, registration, registrationSocial, loginSocial, sendEmailCode, confirmEmail, confirmCode, resetPassword, findUser |
| **UserDAO** | User | info, rating, viewers, budgeCount, user(id), updateProfile, updatePassword, deleteAccount, changeRole, listWithWallets, savePushToken, sendTestPush |
| **PublicationDAO** | Publication | list, feed, create, like, unlike, update(id), delete(id) |
| **EventDAO** | Event | list, create, update(id), applies(id), event(id), delete(id), types, apply, like(id), unlike(id), userApplies |
| **FileDAO** | File | uploadFile(multipart), uploadFiles(multipart), resize(url, width, height) |
| **AgencyDAO** | Agency | list, agency(id), update, modelsList(agencyId), removeModel(agencyId, modelId) |
| **AgencyEmployeeDAO** | Agency Employee | roles |
| **CustomerDAO** | Customer | roles |
| **GeoDAO** | Geo | searchByAddressName(q), searchGeocoder(q) |
| **FeedlineDAO** | Feedline | list, like, unlike, userActivity, search, report, feedline(id) |
| **FollowerDAO** | Follower | follow, unfollow, following, followers |
| **FavoriteDAO** | Favorite | mark, unmark, list |
| **UserGalleryDAO** | User Gallery | add(multipart), list, delete(id), like, unlike |
| **SocialNetworkDAO** | Social Network | list, instagramImport, instagramAdd, instagramUpdate(id), instagramDelete(id) |
| **UserSocialNetworkDAO** | User Social Network | list, upsert, delete(id) |
| **MessengerDAO** | Messenger | pinMessage, unpinMessage, pinned, threadSearch, messages, images, documents, threadsSearch, startDialog, blockUser, unblockUser, block(recipientId), getUsersForMessenging, threadLeave, privatesToken, privatesPhone, friends |
| **DictionaryDAO** | Dictionary | gender, appearances, payments, feedReportTypes |
| **UserGeopositionDAO** | User Geoposition | add |
| **RadarDAO** | Radar | get, set, delete, models, places, place(id), placeReviewsList(id), placeReviewsAdd(id) |
| **WalletDAO** | Wallet | list, withdrawalNetworks, bonus, wallet(walletId), operations, withdraw, send |
| **UserPaidServicesDAO** | User Paid Services | list, checkBalance, buy |
| **NFTDAO** | NFT | create, nft(id), delete(id), update(id), list, buy(id) |
| **BannersDAO** | Banners | get, list, close(id) |
| **SystemDAO** | System | featureFlags |
| **CryptoDAO** | Crypto (no auth) | webhookGet, webhookPost, webhookPut, webhookPatch, webhookDelete |

Methods that take `body: [String: Any]?` send the dictionary as JSON; pass `nil` when the endpoint has no body or an empty body.

## Models

- **Auth**: `LoginRequest`, `LoginResponse` (accessToken), `RegistrationRequest`, `SocialAuthRequest`, `SendEmailCodeRequest`, `ConfirmEmailRequest`, `ResetPasswordRequest`, `FindUserRequest`.
- **User**: `UserInfo` (placeholder with `id`, `email`; extend as the API contract is defined).
- **Common**: `DivoAPIError`, `DivoAPIErrorPayload` (for 422 payloads).

For endpoints whose response shape is not yet defined in the spec, DAO methods return `Data`; decode in your code or introduce new `Codable` types in the module when the contract is fixed.

## Conventions

- **Naming**: PascalCase for types, camelCase for methods and parameters.
- **Threading**: Use from any context; `URLSession` and `async/await` handle concurrency. No main-thread requirement.
- **Idempotency**: The client does not retry; implement retries in the app if needed.

## API spec

The DAL follows the Divo API described in the project’s `openapi.yaml` (base path `/api`, Bearer JWT). Path and method constants live in `APIPath` and `HTTPMethod` in the module.
