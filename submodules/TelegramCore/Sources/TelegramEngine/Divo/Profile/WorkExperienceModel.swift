public class WorkExperienceModel {
    public let id: Int
    public let companyName: String
    public let period: String
    public let logoName: String?
    
    public init(id: Int, companyName: String, period: String, logoName: String?) {
        self.id = id
        self.companyName = companyName
        self.period = period
        self.logoName = logoName
    }
}
