class User < ApplicationRecord
  has_many :record_ratings, inverse_of: :user, dependent: :destroy

  devise :database_authenticatable,
         :recoverable,
         :rememberable,
         :validatable
end
