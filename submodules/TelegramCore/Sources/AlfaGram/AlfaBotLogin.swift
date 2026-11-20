import Foundation
import Postbox
import SwiftSignalKit
internal import TelegramApi
import MtProtoKit

public enum AlfaBotLoginError {
    case invalidToken
    case limitExceeded
    case generic(String)
}

/// AlfaGram: logs in as a bot with its @BotFather token (`auth.importBotAuthorization`).
/// A bot account sees only what arrives after the login: bots cannot load the chat list or old history.
public func alfaAuthorizeWithBotToken(accountManager: AccountManager<TelegramAccountManagerTypes>, account: UnauthorizedAccount, token: String, apiId: Int32, apiHash: String) -> Signal<Never, AlfaBotLoginError> {
    let request = Api.functions.auth.importBotAuthorization(flags: 0, apiId: apiId, apiHash: apiHash, botAuthToken: token)

    let authorized: Signal<(Api.auth.Authorization, UnauthorizedAccount), MTRpcError> = account.network.request(request, automaticFloodWait: false)
    |> map { result -> (Api.auth.Authorization, UnauthorizedAccount) in
        return (result, account)
    }
    |> `catch` { error -> Signal<(Api.auth.Authorization, UnauthorizedAccount), MTRpcError> in
        // The bot lives on another data center: move there and ask again.
        let description: String = error.errorDescription ?? ""
        if let range = description.range(of: "MIGRATE_"), let datacenterId = Int32(description[range.upperBound...]) {
            return account.changedMasterDatacenterId(accountManager: accountManager, masterDatacenterId: datacenterId)
            |> mapToSignalPromotingError { updatedAccount -> Signal<(Api.auth.Authorization, UnauthorizedAccount), MTRpcError> in
                return updatedAccount.network.request(request, automaticFloodWait: false)
                |> map { result -> (Api.auth.Authorization, UnauthorizedAccount) in
                    return (result, updatedAccount)
                }
            }
        }
        return .fail(error)
    }

    return authorized
    |> mapError { error -> AlfaBotLoginError in
        let description: String = error.errorDescription ?? ""
        if description.hasPrefix("FLOOD_WAIT") {
            return .limitExceeded
        } else if description.contains("TOKEN") {
            return .invalidToken
        } else {
            return .generic(description)
        }
    }
    |> mapToSignal { result, account -> Signal<Never, AlfaBotLoginError> in
        return account.postbox.transaction { transaction -> Signal<Void, NoError> in
            switch result {
            case let .authorization(authorizationData):
                let user = TelegramUser(user: authorizationData.user)
                let state = AuthorizedAccountState(isTestingEnvironment: account.testingEnvironment, masterDatacenterId: account.masterDatacenterId, peerId: user.id, state: nil, invalidatedChannels: [])
                initializedAppSettingsAfterLogin(transaction: transaction, appVersion: account.networkArguments.appVersion, syncContacts: false)
                transaction.setState(state)
                return accountManager.transaction { transaction -> Void in
                    switchToAuthorizedAccount(transaction: transaction, account: account, isSupportUser: false)
                }
            case .authorizationSignUpRequired:
                return .complete()
            }
        }
        |> switchToLatest
        |> castError(AlfaBotLoginError.self)
        |> ignoreValues
    }
}
