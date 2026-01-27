public class WorkExperienceModel {
    public let companyName: String
    public let period: String
    public let logoName: String?
    
    public init(companyName: String, period: String, logoName: String?) {
        self.companyName = companyName
        self.period = period
        self.logoName = logoName
    }
}
